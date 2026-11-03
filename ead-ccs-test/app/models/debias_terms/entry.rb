# frozen_string_literal: true

module DebiasTerms
  # One line of the term list (config/debias_terms.yml): a word or phrase, how to match it, and what to tell the visitor. Entry.parse
  # checks a hash (from the YAML or from a spreadsheet row) and answers the entry or the reasons it is not valid, so the
  # importer and the loader judge an entry the same way.
  Entry = Data.define(:id, :term, :match, :case_mode, :languages, :fields, :explanation, :alternative, :severity, :source,
                      :reviewed_on, :enabled)

  class Entry
    MATCHES = %w[word phrase prefix].freeze
    CASES = %w[insensitive sensitive].freeze
    SEVERITIES = %w[note caution].freeze
    MAX_TERM = 100
    MIN_PREFIX = 3
    MAX_TEXT = 1000
    # Characters that mean something in a pattern or a spreadsheet wildcard. Terms are plain text, so these are mistakes.
    PATTERN_CHARACTERS = /[*?\\|^$\[\](){}<>+]/
    ID = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
    LANGUAGE = /\A[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})*\z/
    YES = %w[true yes y 1 on].freeze
    NO = %w[false no n 0 off].freeze

    # [entry, []] when valid; [nil, ["reason", ...]] when not. `hash` has string keys: id, term, match, case, languages, fields,
    # explanation, alternative, severity, source, reviewed_on, enabled.
    def self.parse(hash)
      errors = []
      term = clean(hash["term"])
      errors << "term is empty" if term.empty?
      errors << "term is longer than #{MAX_TERM} characters" if term.length > MAX_TERM
      errors << "term #{term.inspect} has pattern characters; write the plain word or phrase" if term.match?(PATTERN_CHARACTERS)
      errors << "term #{term.inspect} has no letters or digits" if term.present? && !term.match?(/[\p{L}\p{N}]/)
      errors << "term has control characters" if term.match?(/[[:cntrl:]]/)

      match = (clean(hash["match"]).downcase.presence || "word")
      errors << "match #{match.inspect} must be one of #{MATCHES.join(', ')}" unless MATCHES.include?(match)
      errors << "a word entry is one word; use match: phrase for #{term.inspect}" if match == "word" && term.match?(/[[:space:]]/)
      errors << "a phrase entry needs two or more words; use match: word for #{term.inspect}" if match == "phrase" && term.split.size < 2
      errors << "a prefix must be at least #{MIN_PREFIX} characters" if match == "prefix" && term.length < MIN_PREFIX

      case_mode = (clean(hash["case"]).downcase.presence || "insensitive")
      errors << "case #{case_mode.inspect} must be one of #{CASES.join(', ')}" unless CASES.include?(case_mode)

      languages = list(hash["languages"]).then { |codes| codes.empty? ? [ "en" ] : codes }
      languages.reject { |code| code.match?(LANGUAGE) }.each { |code| errors << "language code #{code.inspect} is not a code such as en or en-AU" }

      fields = list(hash["fields"]).map(&:downcase).then { |names| names.empty? ? [ "all" ] : names }
      fields.reject { |name| DebiasTerms::FIELD_GROUPS.key?(name) || DebiasTerms::SCANNED_FIELDS.include?(name) || name == "all" }
            .each { |name| errors << "field #{name.inspect} is not all, #{DebiasTerms::FIELD_GROUPS.keys.join(', ')}" }

      explanation = clean(hash["explanation"])
      errors << "explanation is required" if explanation.empty?
      errors << "explanation is longer than #{MAX_TEXT} characters" if explanation.length > MAX_TEXT
      alternative = clean(hash["alternative"])
      errors << "alternative is longer than #{MAX_TEXT} characters" if alternative.length > MAX_TEXT

      severity = (clean(hash["severity"]).downcase.presence || "note")
      errors << "severity #{severity.inspect} must be one of #{SEVERITIES.join(', ')}" unless SEVERITIES.include?(severity)

      source = clean(hash["source"])
      errors << "source is required" if source.empty?

      reviewed_on = date(hash["reviewed_on"])
      errors << "reviewed_on must be a date such as 2026-11-03" if reviewed_on.nil?

      enabled = flag(hash["enabled"])
      errors << "enabled #{hash['enabled'].inspect} must be true or false" if enabled.nil?

      id = clean(hash["id"]).presence || default_id(term)
      errors << "id #{id.inspect} must be lower case letters, digits and hyphens" unless id.match?(ID)

      return [ nil, errors ] if errors.any?

      [ new(id: id, term: term.unicode_normalize(:nfc), match: match, case_mode: case_mode, languages: languages, fields: fields.uniq,
            explanation: explanation, alternative: alternative.presence, severity: severity, source: source, reviewed_on: reviewed_on,
            enabled: enabled), [] ]
    end

    # "Some term" becomes some-term; a term with no Latin letters (another script) gets term- and a short hash of itself
    def self.default_id(term)
      slug = term.downcase.unicode_normalize(:nfkd).gsub(/\p{M}/, "").gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
      slug.presence || "term-#{Digest::SHA256.hexdigest(term.downcase)[0, 10]}"
    end

    def self.clean(value) = value.to_s.unicode_normalize(:nfc).squish

    # "en; fr" or "en, fr" or ["en", "fr"]
    def self.list(value) = Array(value).flat_map { |item| item.to_s.split(/[;,|]/) }.map { |item| clean(item) }.compact_blank

    def self.date(value)
      return value if value.is_a?(Date)

      Date.iso8601(value.to_s.strip)
    rescue Date::Error
      nil
    end

    # true, false or nil when it is neither; blank is false (a new entry is reviewed before it is switched on)
    def self.flag(value)
      return value if [ true, false ].include?(value)

      text = value.to_s.strip.downcase
      return false if text.empty? || NO.include?(text)

      YES.include?(text) ? true : nil
    end

    # What is written to config/debias_terms.yml
    def to_h
      { "id" => id, "term" => term, "match" => match, "case" => case_mode, "languages" => languages, "fields" => fields,
        "explanation" => explanation, "alternative" => alternative, "severity" => severity, "source" => source,
        "reviewed_on" => reviewed_on.iso8601, "enabled" => enabled }.compact
    end

    def caution? = severity == "caution"
  end
end
