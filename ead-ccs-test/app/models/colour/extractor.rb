# frozen_string_literal: true

require "csv"

module Colour
  # rake colour:extract: the colours of every record with a viewable image in the writable core (DAM_SOLR_URL), into record_colours.
  #
  # Resumable: a record already done for the same image is skipped, so a stopped run picks up where it was (FRESH=1 does them all
  # again); one whose image could not be read is tried again. Rate-limited: at most `rate` image requests a second to the DAM
  # (COLOUR_RATE, default 4); files this site holds are read from disk. Reports what it did, and writes the failures to a CSV.
  class Extractor
    FILTERS = [ "has_digital_asset_bsi:true", "thumbnail_path_ssi:[* TO *]" ].freeze

    Report = Struct.new(:seen, :extracted, :skipped, :failed, :reasons, :names, keyword_init: true) do
      def to_s
        lines = [ "#{seen} records with an image: #{extracted} read, #{skipped} already done, #{failed} could not be read" ]
        lines << "Colour names: #{names.sort_by { |_name, count| -count }.map { |name, count| "#{name} #{count}" }.join(', ')}" if names.any?
        lines << "Why not: #{reasons.map { |reason, count| "#{reason} (#{count})" }.join('; ')}" if reasons.any?
        lines.join("\n")
      end
    end

    def initialize(solr:, fetcher: Fetcher.new, rate: Float(ENV.fetch("COLOUR_RATE", 4)), fresh: false, limit: nil,
                   failures_csv: Rails.root.join("tmp/colour_extract_failures.csv"), logger: Rails.logger, sleeper: ->(seconds) { sleep(seconds) })
      @solr = solr
      @fetcher = fetcher
      @interval = rate.positive? ? 1.0 / rate : 0
      @fresh = fresh
      @limit = limit
      @failures_csv = failures_csv
      @logger = logger
      @sleeper = sleeper
      @report = Report.new(seen: 0, extracted: 0, skipped: 0, failed: 0, reasons: Hash.new(0), names: Hash.new(0))
      @failures = []
    end

    def run
      catch(:limit) do
        WritableCore.each_batch(@solr, fl: "id,thumbnail_path_ssi", fq: FILTERS) do |docs|
          done = RecordColour.where(record_id: docs.map { |doc| doc["id"] }).index_by(&:record_id)
          docs.each { |doc| process(doc, done[doc["id"]]) }
        end
      end
      write_failures
      @report
    end

    private

    def process(doc, row)
      throw :limit if @limit && (@report.extracted + @report.failed) >= @limit

      @report.seen += 1
      url = doc["thumbnail_path_ssi"].to_s
      return @report.skipped += 1 if !@fresh && row && row.error.nil? && row.image_url == url

      palette = Palette.new(Png.pixels(fetch(url)))
      save(doc["id"], url, palette.to_h.merge("error" => nil))
      palette.names.each { |name| @report.names[name] += 1 }
      @report.extracted += 1
      @logger.info("[colour] #{@report.extracted} read") if (@report.extracted % 100).zero?
    rescue Fetcher::Refused, Fetcher::Failed, Png::Unsupported, ArgumentError => e
      failed(doc["id"], url, e)
    end

    def fetch(url)
      return @fetcher.png(url) if url.start_with?(Fetcher::LOCAL_PREFIX)
      raise Fetcher::Refused, "not an allowed image address" unless @fetcher.remote_uri(url) # refused at once: no wait, no request

      wait = @last_request ? @interval - (monotonic - @last_request) : 0
      @sleeper.call(wait) if wait.positive?
      @last_request = monotonic
      @fetcher.png(url)
    end

    def failed(id, url, error)
      reason = "#{error.class.name.demodulize}: #{error.message}"
      save(id, url, "palette" => [], "buckets" => [], "histogram" => {}, "error" => reason.first(250))
      @report.failed += 1
      @report.reasons[reason] += 1
      @failures << [ id, url, reason ]
    end

    def save(id, url, attributes)
      now = Time.current
      RecordColour.upsert({ record_id: id, image_url: url, extracted_at: now, created_at: now, updated_at: now }.merge(attributes.symbolize_keys),
                          unique_by: :record_id, update_only: %i[image_url palette buckets histogram error extracted_at])
    end

    def write_failures
      return if @failures.empty?

      FileUtils.mkdir_p(File.dirname(@failures_csv))
      CSV.open(@failures_csv, "w") do |csv|
        csv << %w[record_id image_url reason]
        @failures.each { |row| csv << row }
      end
    end

    def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
