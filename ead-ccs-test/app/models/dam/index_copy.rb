# frozen_string_literal: true

module Dam
  # Copies every record of one Solr core into another (rake dam:copy_index): the DAM sync writes to a core of its own, made
  # from the shared one, which is only read. Stored fields are copied (fl=*: the request handler's default list adds the
  # score); copyField targets are left for the target core to build again, and _version_ to set anew. Both cores use the same
  # schema (the ccs2027-solr image), in which every field a record carries is stored, so nothing is lost in the copy or in a
  # later atomic update.
  class IndexCopy
    BATCH = 1_000

    def initialize(from:, to:, logger: Rails.logger)
      raise Error, "copying a core onto itself" if from.to_s.chomp("/") == to.to_s.chomp("/")

      @from = RSolr.connect(url: from)
      @to = RSolr.connect(url: to)
      @logger = logger
    end

    # Returns the number of records copied
    def run
      skipped = copy_targets + [ "_version_" ]
      cursor = "*"
      copied = 0
      loop do
        response = @from.get("select", params: { q: "*:*", fl: "*", sort: "id asc", rows: BATCH, cursorMark: cursor, wt: "json" })
        docs = response.dig("response", "docs") || []
        break if docs.empty?

        @to.add(docs.map { |doc| doc.except(*skipped) })
        copied += docs.size
        @logger.info("[dam] copied #{copied}/#{response.dig('response', 'numFound')} records") if (copied % 10_000).zero?
        break if response["nextCursorMark"] == cursor

        cursor = response["nextCursorMark"]
      end
      @to.commit
      copied
    end

    private

    def copy_targets
      Array(@from.get("schema/copyfields", params: { wt: "json" })["copyFields"]).map { |copy| copy["dest"] }.uniq
    end
  end
end
