# frozen_string_literal: true

require "csv"

module DebiasTerms
  # Turns the collections team's spreadsheet (saved as CSV) into the term list. Checks the columns, every row (the same rules as the
  # app uses when it loads the list, Entry.parse) and duplicates, and reports every problem with its row number, so the sheet can
  # be fixed in one pass. It writes nothing itself: `bin/rails debias:import` writes `yaml` when `errors` is empty.
  #
  # Columns (heading names are not case sensitive; spaces and hyphens are the same as underscores; order does not matter):
  #   required   term, explanation, source, reviewed_on
  #   optional   id, match, case, languages, fields, alternative, severity, enabled
  # In a list cell, separate values with a semicolon (en; fr). A blank `enabled` is false: an entry is switched on deliberately.
  class Importer
    REQUIRED = %w[term explanation source reviewed_on].freeze
    OPTIONAL = %w[id match case languages fields alternative severity enabled].freeze
    MAX_ROWS = DebiasTerms::MAX_ENTRIES
    MAX_BYTES = 5_000_000
    ALIASES = { "reviewed" => "reviewed_on", "reviewed_date" => "reviewed_on", "date_reviewed" => "reviewed_on",
                "case_handling" => "case", "match_mode" => "match", "suggested_alternative" => "alternative",
                "suggested_neutral_alternative" => "alternative", "owner" => "source", "language" => "languages" }.freeze

    Result = Data.define(:entries, :errors, :warnings) do
      def ok? = errors.empty?
    end

    def initialize(csv_text)
      @text = csv_text.to_s
    end

    def self.read(path)
      raise ArgumentError, "#{path} is not a file" unless File.file?(path)
      raise ArgumentError, "#{path} is larger than #{MAX_BYTES} bytes" if File.size(path) > MAX_BYTES

      new(File.read(path, encoding: "bom|utf-8"))
    end

    def call
      errors = []
      warnings = []
      table = parse(errors)
      return Result.new([], errors, warnings) unless table

      headers = table.headers.map { |header| normalise_header(header) }
      check_headers(headers, errors, warnings)
      return Result.new([], errors, warnings) if errors.any?

      entries = []
      table.each_with_index do |row, index|
        line = index + 2 # the heading is row 1
        hash = headers.zip(row.fields).to_h.compact_blank.except(nil)
        next if hash.values.all?(&:blank?)

        entry, problems = Entry.parse(hash)
        problems.each { |problem| errors << "row #{line}: #{problem}" }
        entries << [ entry, line ] if entry
      end
      errors << "the sheet has more than #{MAX_ROWS} rows" if entries.size > MAX_ROWS
      duplicates(entries, errors)
      warnings << "#{entries.count { |entry, _| !entry.enabled }} of #{entries.size} entries are not enabled and will be ignored by the site" if entries.any? { |entry, _| !entry.enabled }
      Result.new(entries.map(&:first), errors, warnings)
    end

    # The file's text: a comment explaining where it came from, then the entries
    def self.yaml(entries)
      header = <<~COMMENT
        # De-bias notices: the term list. Written by `bin/rails debias:import` from the collections team's spreadsheet.
        # The schema is documented in docs/debias-terms.md. Edit the spreadsheet and import again rather than editing this file.
      COMMENT
      header + { "terms" => entries.map(&:to_h) }.to_yaml.delete_prefix("---\n")
    end

    private

    def parse(errors)
      return fail_with(errors, "the file is empty") if @text.strip.empty?
      return fail_with(errors, "the file is not valid UTF-8 text; save the sheet as CSV UTF-8") unless @text.dup.force_encoding("UTF-8").valid_encoding?

      CSV.parse(@text.dup.force_encoding("UTF-8").delete_prefix("﻿"), headers: true, skip_blanks: true)
    rescue CSV::MalformedCSVError => e
      fail_with(errors, "the file is not valid CSV (#{e.message.sub(/ in line .*/, '')})")
    end

    def fail_with(errors, message)
      errors << message
      nil
    end

    def normalise_header(header)
      name = header.to_s.strip.downcase.gsub(/[\s-]+/, "_")
      ALIASES.fetch(name, name)
    end

    def check_headers(headers, errors, warnings)
      (REQUIRED - headers).each { |name| errors << "the sheet has no #{name} column" }
      headers.tally.each { |name, count| errors << "the #{name} column appears #{count} times" if count > 1 && name.present? }
      (headers - REQUIRED - OPTIONAL).reject(&:blank?).each { |name| warnings << "the #{name} column is not used" }
    end

    # The same term, match mode and case twice (what the matcher would treat as one), or the same id
    def duplicates(entries, errors)
      first_seen = {}
      entries.each do |entry, line|
        keys = [ [ :id, entry.id ], [ :term, entry.term.then { |t| entry.case_mode == "sensitive" ? t : t.downcase }, entry.match, entry.case_mode ] ]
        keys.each do |key|
          if (earlier = first_seen[key]) then errors << "row #{line}: duplicate of row #{earlier} (#{key.first == :id ? 'same id' : 'same term, match and case'})"
          else first_seen[key] = line
          end
        end
      end
    end
  end
end
