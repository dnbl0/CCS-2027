# frozen_string_literal: true

module DebiasTerms
  # Which enabled terms occur in the records, and how often, to review the list before it goes live (`bin/rails debias:report`).
  # It reads the index only (a cursor over `select`, never an update), runs the same matcher as the record page over the same
  # fields, and counts per entry. `records` answers #call with a block-less enumerator or array of hashes of Solr documents; by
  # default it reads Solr. Tests hand one in.
  class Report
    ROWS = 1000
    EXAMPLES = 3

    Line = Data.define(:entry, :records, :occurrences, :examples)

    def initialize(records: Source)
      @records = records
    end

    # [Line, ...] for every enabled entry, commonest first; a term found nowhere has zero
    def call(scanned: nil)
      totals = DebiasTerms.enabled.to_h { |entry| [ entry.id, { records: 0, occurrences: 0, examples: [] } ] }
      count = 0
      @records.call.each do |doc|
        count += 1
        DebiasTerms.scan(SCANNED_FIELDS.index_with { |field| Array(doc[field]) }).group_by { |match| match.entry.id }.each do |id, found|
          total = totals.fetch(id)
          total[:records] += 1
          total[:occurrences] += found.size
          total[:examples] << doc["id"] if total[:examples].size < EXAMPLES
        end
      end
      scanned&.call(count)
      DebiasTerms.enabled.map { |e| Line.new(e, *totals.fetch(e.id).values_at(:records, :occurrences, :examples)) }
                 .sort_by { |line| [ -line.records, line.entry.term.downcase ] }
    end

    # Every record's displayed text fields, read from Solr with a cursor
    module Source
      def self.call(connection = Blacklight.default_index.connection)
        Enumerator.new do |out|
          cursor = "*"
          loop do
            response = connection.get("select", params: { q: "*:*", sort: "id asc", rows: ROWS, cursorMark: cursor, fl: (%w[id] + SCANNED_FIELDS).join(","), wt: "json" })
            response["response"]["docs"].each { |doc| out << doc }
            break if response["nextCursorMark"].nil? || response["nextCursorMark"] == cursor

            cursor = response["nextCursorMark"]
          end
        end
      end
    end
  end
end
