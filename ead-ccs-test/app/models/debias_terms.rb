# frozen_string_literal: true

require "yaml"
require "date"

# De-bias notices: finds words and phrases in the text a record page shows that the collections team has listed as possibly
# offensive or outdated (config/debias_terms.yml; docs/debias-terms.md explains it in plain language). The list ships with no real
# terms, so by default nothing is found and the record page is unchanged.
#
# What it does: scan(fields) answers the Matches (which entry, which field, where). What it never does: change a record. The
# text stays as the catalogue holds it; NexusCcs::DebiasNoticeComponent and the record page only add a notice and mark the term.
#
# Safety. A term is plain text: it is escaped, never run as a pattern, so a hostile list cannot inject one, and the compiled matcher
# is a literal with a word boundary at each end, which cannot backtrack catastrophically (a phrase's gaps are one run of spaces
# between literals). Input is bounded (MAX_LENGTH characters of each value, MAX_VALUES values of a field, MAX_MATCHES in all),
# and each pattern has a time limit as a last resort. An unreadable list or a bad entry is logged and skipped; it never breaks a page.
#
#   word    whole word: not inside a longer word, in any script (\p{L}\p{N}\p{M} bound it)
#   phrase  the words in order, any spacing between them
#   prefix  a word that starts with the term
module DebiasTerms
  PATH = Rails.root.join("config/debias_terms.yml")

  # Only text the record page displays (RecordDocumentComponent's details list). The id, collection names, accession number,
  # parent record and the copyright card's fields are not text a term is looked for in.
  FIELD_GROUPS = {
    "title" => %w[title_tsim],
    "description" => %w[description_tsim],
    "subject" => %w[subject_ssim classification_ssim object_type_ssim],
    "place" => %w[production_place_ssim],
    "names" => %w[creator_display_ssim associated_entity_ssim cultural_group_ssim series_ssim],
    "material" => %w[material_ssim],
    # Not in the index yet (the workbook has gaps for notes and inscriptions); named so an entry can be written for when they are
    "notes" => %w[notes_tsim],
    "inscription" => %w[inscription_tsim]
  }.freeze
  SCANNED_FIELDS = FIELD_GROUPS.values.flatten.freeze

  MAX_LENGTH = 10_000
  MAX_VALUES = 50
  MAX_MATCHES = 100
  MAX_ENTRIES = 5000
  PATTERN_TIMEOUT = 0.25 # seconds, per pattern; a literal pattern needs microseconds

  # One find: the entry, the field, which value of the field, and where in the (normalised) text; `text` is that value
  Match = Data.define(:entry, :field, :value_index, :start, :finish, :text) do
    def found = text[start...finish]

    # The words around the find: [before, found, after], each cut at a word and shortened to about `radius` characters
    def context(radius = 40)
      before = text[0...start].to_s
      after = text[finish..].to_s
      before = "…#{before.last(radius).sub(/\A\S*\s/, '')}" if before.length > radius
      after = "#{after.first(radius).sub(/\s\S*\z/, '')}…" if after.length > radius
      [ before, found, after ]
    end
  end

  Matcher = Data.define(:entry, :regex, :fields)

  class << self
    # Every entry in the list, enabled or not
    def entries = @entries ||= load_entries

    def enabled = entries.select(&:enabled)

    def any? = matchers.any?

    # values_by_field: { "title_tsim" => ["A title"], ... } (what the page displays). Matches in field order, then by position.
    def scan(values_by_field)
      list = matchers
      return [] if list.empty?

      matches = []
      values_by_field.each do |field, values|
        field = field.to_s
        next unless SCANNED_FIELDS.include?(field)

        Array(values).first(MAX_VALUES).each_with_index do |value, index|
          # Cut before normalising: Unicode normalisation is regex-based and Rails' global Regexp.timeout (1 s) would stop it on a
          # multi-megabyte value. Twice the window leaves room for normalisation to shrink the text.
          text = normalise(value.to_s[0, MAX_LENGTH * 2])
          next if text.empty?

          window = text[0, MAX_LENGTH]
          list.each do |matcher|
            next unless matcher.fields.include?(field)

            each_range(matcher.regex, window) { |start, finish| matches << Match.new(matcher.entry, field, index, start, finish, text) }
            return finish_scan(matches) if matches.size >= MAX_MATCHES
          end
        end
      end
      finish_scan(matches)
    end

    # Text as the scan sees it: valid UTF-8, composed (NFC). Positions in a Match are positions in this.
    def normalise(value) = value.to_s.scrub("").unicode_normalize(:nfc)

    # Use `list` (entries or hashes with the list's keys) instead of the file, for the block. For tests.
    def use(list)
      saved = [ @entries, @matchers ]
      @entries = Array(list).filter_map { |item| item.is_a?(Entry) ? item : Entry.parse(item.transform_keys(&:to_s)).first }
      @matchers = nil
      yield
    ensure
      @entries, @matchers = saved
    end

    def reload!
      @entries = @matchers = nil
    end

    # Fields an entry applies to
    def fields_for(entry)
      entry.fields.flat_map { |name| name == "all" ? SCANNED_FIELDS : (FIELD_GROUPS[name] || [ name ]) }.uniq & SCANNED_FIELDS
    end

    # The matcher for one entry: a literal between word boundaries
    def compile(entry)
      literal = case entry.match
      when "phrase" then entry.term.split.map { |word| Regexp.escape(word) }.join("[[:space:]]+")
      else Regexp.escape(entry.term)
      end
      ahead = entry.match == "prefix" ? "" : "(?![\\p{L}\\p{N}\\p{M}])"
      options = entry.case_mode == "sensitive" ? 0 : Regexp::IGNORECASE
      Matcher.new(entry, Regexp.new("(?<![\\p{L}\\p{N}\\p{M}])#{literal}#{ahead}", options, timeout: PATTERN_TIMEOUT), fields_for(entry))
    end

    private

    def matchers = @matchers ||= enabled.map { |entry| compile(entry) }

    def each_range(regex, text)
      position = 0
      while (found = regex.match(text, position))
        yield found.begin(0), found.end(0)
        position = [ found.end(0), found.begin(0) + 1 ].max
      end
    rescue Regexp::TimeoutError
      Rails.logger.warn("DebiasTerms: a pattern timed out and was skipped")
    end

    def finish_scan(matches)
      matches.first(MAX_MATCHES).sort_by.with_index { |match, i| [ SCANNED_FIELDS.index(match.field), match.value_index, match.start, i ] }
    end

    def load_entries(path = PATH)
      return [] unless File.exist?(path)

      terms = YAML.safe_load_file(path, permitted_classes: [ Date ])&.fetch("terms", nil)
      seen = Set.new
      Array(terms).first(MAX_ENTRIES).each_with_index.filter_map do |hash, index|
        entry, errors = hash.is_a?(Hash) ? Entry.parse(hash.transform_keys(&:to_s)) : [ nil, [ "is not an entry" ] ]
        reason = errors.join("; ") if entry.nil?
        reason = "duplicate id #{entry.id}" if entry && !seen.add?(entry.id)
        if reason
          Rails.logger.warn("DebiasTerms: entry #{index + 1} skipped: #{reason}")
          next
        end
        entry
      end
    rescue Psych::Exception, SystemCallError, NoMethodError => e
      Rails.logger.warn("DebiasTerms: #{path} could not be read: #{e.class}")
      []
    end
  end
end
