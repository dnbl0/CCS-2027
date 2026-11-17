# frozen_string_literal: true

module Dam
  # Keeps dam_assets (DamAsset) up to date with the Nexus DAM, then has Dam::SolrWriter rewrite the index fields of the records
  # whose assets changed.
  #
  #   full         every asset (rake dam:sync FULL=1)
  #   incremental  the assets edited since the last finished run started, with a little overlap (DamSyncJob, every 10 minutes)
  #   reconcile    every asset id the DAM still has; a row the DAM no longer has is marked deleted (DamSyncJob, weekly)
  #
  # The DAM is read by last edit date: everything before DAM_SYNC_EPOCH, then a month at a time, and a range with more than
  # MAX_RANGE assets is halved until each part can be paged by offset (Dam::Client explains why not the scroll). A full run
  # saves the end of each range it finishes, so a run that stopped resumes there. A range that comes back short (an asset
  # edited while it was read) is read again.
  class Sync
    EPOCH = Time.utc(2010, 1, 1)
    # Well under Client::OFFSET_LIMIT, so a range that grows while it is read can still be paged
    MAX_RANGE = 5_000
    # An incremental run reads from a little before the last run started, so an edit saved while that run was reading is not missed
    OVERLAP = 10.minutes
    # A reconcile that sees fewer ids than this share of the live rows marks nothing deleted: something is wrong with the read
    RECONCILE_FLOOR = 0.9
    READ_ATTEMPTS = 3
    PROGRESS_EVERY = 1_000

    def self.epoch = ENV["DAM_SYNC_EPOCH"].present? ? Time.iso8601(ENV["DAM_SYNC_EPOCH"]) : EPOCH

    def initialize(client: Client.from_env, writer: SolrWriter.from_env, logger: Rails.logger, now: -> { Time.current })
      @client = client
      @writer = writer
      @logger = logger
      @now = now
    end

    # resume: false starts again from the beginning even when an earlier full run stopped part way
    def full(resume: true)
      run = (DamSyncRun.unfinished_full if resume) || DamSyncRun.create!(kind: "full", started_at: @now.call)
      run.update!(status: "running", error: nil, finished_at: nil)
      log("full sync #{run.checkpoint ? "resumed from #{run.checkpoint.iso8601}" : 'started'} (run #{run.id})")
      months(run.checkpoint, run.started_at).each do |from, to|
        each_range(from, to) do |range_from, range_to|
          upsert_range(range_from, range_to, run)
          run.update!(checkpoint: range_to)
        end
      end
      # A resumed run does not know which records the stopped one touched, so every record with an asset is looked at;
      # the writer only sends the records whose fields changed
      finish(run, DamAsset.distinct.pluck(:accession_number))
    rescue StandardError => e
      run&.fail!(e)
      raise
    end

    def incremental
      since = DamSyncRun.last_started_at
      raise Error, "no finished DAM sync yet: run a full one first (rake dam:sync FULL=1)" unless since

      run = DamSyncRun.create!(kind: "incremental", started_at: @now.call, updated_since: since - OVERLAP)
      touched = Set.new
      each_range(run.updated_since, run.started_at) { |from, to| touched.merge(upsert_range(from, to, run)) }
      finish(run, touched)
    rescue StandardError => e
      run&.fail!(e)
      raise
    end

    def reconcile
      run = DamSyncRun.create!(kind: "reconcile", started_at: @now.call)
      ids = Set.new
      months(nil, run.started_at).each do |month_from, month_to|
        each_range(month_from, month_to) do |from, to|
          ids.merge(read_range(from, to, run, expand: false).flat_map { |items| items.map { |item| item["id"] } })
        end
      end
      live = DamAsset.live.count
      raise Error, "the DAM listed #{ids.size} assets for #{live} live rows; nothing marked deleted" if ids.size < live * RECONCILE_FLOOR

      gone = DamAsset.live.where.not(dam_id: ids.to_a)
      touched = gone.distinct.pluck(:accession_number)
      count = gone.update_all(deleted_at: @now.call, updated_at: @now.call)
      missing = ids.size - DamAsset.where(dam_id: ids.to_a).count
      log("reconcile: #{count} assets gone from the DAM; #{missing} DAM assets not in dam_assets yet#{' (run a full sync)' if missing.positive?}")
      finish(run, touched)
    rescue StandardError => e
      run&.fail!(e)
      raise
    end

    private

    # [from, to] month ranges: everything up to the epoch, then a month at a time to the run's start; those ending at or
    # before the checkpoint are done
    def months(checkpoint, until_time)
      edges = [ Time.utc(1970, 1, 1), self.class.epoch ]
      edges << edges.last.next_month while edges.last.next_month < until_time
      edges << until_time
      pairs = edges.each_cons(2).to_a
      return pairs unless checkpoint

      pairs.reject { |_from, to| to <= checkpoint }.map { |from, to| [ [ from, checkpoint ].max, to ] }
    end

    # Yields [from, to] parts of a range, in time order, each matching at most MAX_RANGE assets
    def each_range(from, to, &block)
      if (to - from) > 1 && @client.count(Client.edited_between(from, to)) > MAX_RANGE
        middle = from + ((to - from) / 2).floor
        each_range(from, middle, &block)
        each_range(middle, to, &block)
      else
        yield from, to
      end
    end

    # The pages of one range, read again when it comes back short
    def read_range(from, to, run, expand: true)
      query = Client.edited_between(from, to)
      attempts = 0
      begin
        attempts += 1
        pages = []
        @client.each_page(query: query, expand: expand) do |items, seen, total|
          pages << items
          progress(run, items.size, seen, total)
        end
        pages
      rescue Client::ShortRead => e
        raise if attempts >= READ_ATTEMPTS

        log("#{e.message}; reading it again")
        retry
      end
    end

    # Reads one range into dam_assets; returns the accession numbers whose assets changed (before and after the change, so an
    # asset moved from one record to another rewrites both)
    def upsert_range(from, to, run)
      touched = Set.new
      read_range(from, to, run).each do |items|
        rows = items.map { |item| DamAsset.attributes_from_api(item) }
        touched.merge(DamAsset.where(dam_id: rows.map { |row| row[:dam_id] }).pluck(:accession_number))
        touched.merge(rows.map { |row| row[:accession_number] })
        DamAsset.upsert_all(rows, unique_by: :dam_id)
      end
      touched.delete(nil)
      touched
    end

    def finish(run, accessions)
      updated = @writer.write(accessions)
      run.finish!
      log("#{run.kind} sync finished: #{run.seen} assets read, #{updated} records updated in the index")
      updated
    end

    def progress(run, read, seen, total)
      run.increment!(:seen, read)
      log("#{run.kind}: #{run.seen} assets read (#{seen}/#{total} of this range)") if (run.seen % PROGRESS_EVERY).zero?
    end

    def log(message) = @logger.info("[dam] #{message}")
  end
end
