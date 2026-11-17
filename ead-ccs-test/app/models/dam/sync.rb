# frozen_string_literal: true

module Dam
  # Keeps dam_assets (DamAsset) up to date with the Nexus DAM, then has Dam::SolrWriter rewrite the index fields of the records
  # whose assets changed.
  #
  #   full         every asset, read in date windows by last edit date (from before DAM_SYNC_EPOCH to the run's start); the
  #                end of each finished window is saved, so a run that stopped resumes from it (rake dam:sync FULL=1)
  #   incremental  the assets edited since the last finished run started, with a little overlap (DamSyncJob, every 10 minutes)
  #   reconcile    every asset id the DAM still has; a row the DAM no longer has is marked deleted (DamSyncJob, weekly)
  class Sync
    # Before this, assets are read in one window; after it, a month at a time
    EPOCH = Time.utc(2010, 1, 1)
    # An incremental run reads from a little before the last run started, so an edit saved while that run was reading is not missed
    OVERLAP = 10.minutes
    # A reconcile that sees fewer ids than this share of the live rows marks nothing deleted: something is wrong with the read
    RECONCILE_FLOOR = 0.9
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
      windows(run.checkpoint, run.started_at).each do |from, to|
        read(Client.edited_between(from, to), run)
        run.update!(checkpoint: to)
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
      touched = read(Client.edited_between(run.updated_since, run.started_at), run)
      finish(run, touched)
    rescue StandardError => e
      run&.fail!(e)
      raise
    end

    def reconcile
      run = DamSyncRun.create!(kind: "reconcile", started_at: @now.call)
      ids = Set.new
      @client.each_page(expand: false) do |items, seen, total|
        ids.merge(items.map { |item| item["id"] })
        progress(run, seen, total)
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

    # [from, to] windows: everything up to the epoch, then a month at a time to the run's start
    def windows(checkpoint, until_time)
      epoch = self.class.epoch
      edges = [ Time.utc(1970, 1, 1), epoch ]
      edges << edges.last.next_month while edges.last.next_month < until_time
      edges << until_time
      pairs = edges.each_cons(2).to_a
      checkpoint ? pairs.reject { |_from, to| to <= checkpoint } : pairs
    end

    # Reads one search into dam_assets; returns the accession numbers whose assets changed (before and after the change, so an
    # asset moved from one record to another rewrites both)
    def read(query, run)
      touched = Set.new
      @client.each_page(query: query) do |items, seen, total|
        rows = items.map { |item| DamAsset.attributes_from_api(item) }
        ids = rows.map { |row| row[:dam_id] }
        touched.merge(DamAsset.where(dam_id: ids).pluck(:accession_number))
        touched.merge(rows.map { |row| row[:accession_number] })
        DamAsset.upsert_all(rows, unique_by: :dam_id)
        run.increment!(:seen, items.size)
        progress(run, seen, total)
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

    def progress(run, seen, total)
      run.update_column(:total, total) if run.total != total
      log("#{run.kind}: #{seen}/#{total} assets") if (seen % PROGRESS_EVERY).zero? || seen == total
    end

    def log(message) = @logger.info("[dam] #{message}")
  end
end
