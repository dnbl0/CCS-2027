require "csv"

module Collections
  # A CSV a staff member prepares by hand (CCS-31, "Upload metadata"), with the documented headers in docs/csv-upload.md, instead of
  # an EMu or Vernon export. Headers are matched without regard to case, spaces or underscores ("Accession Number" = accession_number);
  # only id and title are required; a column the app does not know is reported, never guessed at.
  #
  # #each_document gives Solr documents like the other sources (so Collections::Indexer takes it); #check reads the same file and
  # reports every problem per row, without producing anything to index.
  class CsvSource < Source
    DELIMITER = /\s*;\s*/
    HEADERS = %w[id title accession_number collection object_type creator date description subject place credit_line rights language source_reference].freeze
    REQUIRED = %w[id title].freeze
    LIST_HEADERS = %w[object_type creator subject place language].freeze
    # The longest a value may be (characters): a cell over this is almost always a pasted document or a broken quote
    LIMITS = { "id" => 100, "title" => 500, "accession_number" => 100, "collection" => 200, "date" => 200, "description" => 10_000 }.freeze
    DEFAULT_LIMIT = 2000
    DEFAULT_FORMAT = "Object".freeze

    Problem = Data.define(:line, :id, :message)
    Report = Data.define(:rows, :documents, :problems, :unknown_columns, :missing_columns) do
      def ok? = problems.empty? && unknown_columns.empty? && missing_columns.empty?
    end

    # The file's text as UTF-8: a byte-order mark is dropped, UTF-16 (Excel's "Unicode Text") is converted, and a file that is not
    # valid UTF-8 is read as Windows-1252 (an older Excel "CSV"), so accented names survive.
    def self.read_text(path)
      bytes = File.binread(path)
      text =
        if bytes.start_with?("\xFF\xFE".b, "\xFE\xFF".b)
          bytes.force_encoding("UTF-16").encode("UTF-8")
        else
          utf8 = bytes.dup.force_encoding("UTF-8")
          utf8.valid_encoding? ? utf8 : bytes.force_encoding("Windows-1252").encode("UTF-8")
        end
      text.delete_prefix("﻿")
    end

    def self.normalise(header) = header.to_s.strip.downcase.gsub(/[\s_-]+/, "_")

    def name = "csv"

    def each_document
      return enum_for(:each_document) unless block_given?

      check(documents: true).documents.each { |document| yield DigitalMedia.default.attach(DigitalAssets.default.attach(document)) }
    end

    # Reads the whole file. documents: false keeps nothing but the report (a huge file need not be held twice).
    def check(documents: false)
      problems = []
      docs = []
      rows = 0
      table = parse(problems)
      headers = table.shift.to_a.map { |header| self.class.normalise(header) }
      problems << Problem.new(1, nil, "the file is empty") if headers.empty? && problems.empty?
      unknown = headers.reject { |header| header.empty? || HEADERS.include?(header) }.uniq
      missing = REQUIRED - headers
      dupes = headers.tally.select { |header, n| n > 1 && !header.empty? }.keys
      dupes.each { |header| problems << Problem.new(1, nil, "the column #{header.inspect} appears more than once") }

      seen = {}
      table.each_with_index do |fields, offset|
        line = offset + 2
        next if fields.all? { |field| field.to_s.strip.empty? }

        rows += 1
        cells = headers.zip(fields).to_h { |header, value| [ header, Text.clean(value) ] }.except("")
        id = cells["id"]
        before = problems.size
        check_row(cells, line, id, problems)
        if id && seen.key?(id)
          problems << Problem.new(line, id, "duplicate id (first on line #{seen[id]})")
        end
        seen[id] ||= line if id
        docs << build(cells) if documents && problems.size == before && id
      end
      Report.new(rows, docs, problems, unknown, missing)
    end

    private

    def parse(problems)
      CSV.parse(self.class.read_text(path), liberal_parsing: false)
    rescue CSV::MalformedCSVError => e
      problems << Problem.new(e.line_number, nil, "the file is not valid CSV: #{e.message}")
      []
    end

    def check_row(cells, line, id, problems)
      REQUIRED.each { |header| problems << Problem.new(line, id, "#{header} is missing") if cells[header].blank? }
      problems << Problem.new(line, id, "id may only have letters, digits and . _ : - (#{id.inspect})") if id && !SuppressedRecord.valid_id?(id)
      cells.each do |header, value|
        next unless value

        limit = LIMITS.fetch(header, DEFAULT_LIMIT)
        problems << Problem.new(line, id, "#{header} is #{value.length} characters; the most is #{limit}") if value.length > limit
      end
      problems << Problem.new(line, id, "date #{cells['date'].inspect} has no year from 1000 on") if cells["date"] && DateRange.parse(cells["date"]).compact.empty?
    end

    def list(cells, header) = cells[header].to_s.split(DELIMITER).filter_map { |value| Text.clean(value) }

    def build(cells)
      start_year, end_year = DateRange.parse(cells["date"])
      creators = list(cells, "creator")
      compact_document(
        "id" => document_id(cells["id"]),
        "source_system_ssi" => name,
        "source_identifier_ssi" => cells["id"],
        "accession_number_ssim" => [ cells["accession_number"] ],
        "source_reference_tsim" => [ cells["source_reference"] ],
        "collection_ssim" => [ cells["collection"] ],
        "object_type_ssim" => list(cells, "object_type"),
        "format" => [ DEFAULT_FORMAT ],
        "title_tsim" => [ cells["title"] ],
        "title_si" => cells["title"],
        "creator_tsim" => creators, "creator_ssim" => creators, "creator_display_ssim" => creators,
        "subject_ssim" => list(cells, "subject"), "subject_tsim" => list(cells, "subject"),
        "production_place_ssim" => list(cells, "place"),
        "production_date_ssim" => [ cells["date"] ],
        "date_start_isi" => start_year, "date_end_isi" => end_year,
        "description_tsim" => [ cells["description"] ],
        "credit_line_tsim" => [ cells["credit_line"] ],
        "rights_ssim" => [ cells["rights"] ],
        "licence_type_ssim" => licence_types([ cells["rights"] ].compact),
        "language_ssim" => list(cells, "language")
      )
    end
  end
end
