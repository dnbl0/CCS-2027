# frozen_string_literal: true

# Why a record matched the search (CCS-39): which fields held the visitor's words, and where in the text. Solr's own
# highlighter does the finding (the unified highlighter, over the stored text fields), so it follows the same analysis as the
# search itself: phrases, wildcards, synonyms, Boolean and fielded queries, and the Advanced search clauses. This module
#   - says what to ask for (.parameters, used by SearchBuilder), which is display-only: `hl*` parameters add a "highlighting"
#     section to the response and cannot change which records match or their order (test/models/search_highlighting_test.rb
#     checks it against the core);
#   - reads the answer for one record (.for), as a Match: the fields it matched in, a snippet, and a way to mark the same
#     words in text the card already shows.
# Every piece of record text that leaves here is escaped, whatever Solr sent: the snippet is rebuilt from Solr's text and its
# <mark> tags only (Match#snippet), and Match#mark escapes the text it is given.
module SearchHighlighting
  # The stored text fields shown as "Matched in". Order is the order of the "Matched in" line. source_reference_tsim and
  # restrictions_tsi are left out on purpose: they carry internal and access notes the site does not show.
  FIELDS = {
    "title_tsim" => :title,
    "alternative_title_tsim" => :alternative_title,
    "creator_tsim" => :creator,
    "subject_tsim" => :subject,
    "description_tsim" => :description,
    "credit_line_tsim" => :credit_line,
    "preferred_citation_tsim" => :citation
  }.freeze

  # The fields whose text can stand as a snippet under the card (the title and creator are on the card already)
  SNIPPET_FIELDS = %w[description_tsim subject_tsim alternative_title_tsim credit_line_tsim preferred_citation_tsim].freeze

  OPEN = "<mark>"
  CLOSE = "</mark>"
  FRAGMENT_SIZE = 160
  MARK_PATTERN = %r{(</?mark>)}

  # The fields each search field looks in (CatalogConfig::SearchFields); any other (all fields) looks in all of them
  SEARCH_FIELD_SCOPE = {
    "title" => %w[title_tsim alternative_title_tsim],
    "creator" => %w[creator_tsim],
    "subject" => %w[subject_tsim],
    "description" => %w[description_tsim]
  }.freeze

  # Solr parameters for the results page. Empty when there is nothing to find (a browse by filter has no search words).
  # search_state: a Blacklight::SearchState
  def self.parameters(search_state)
    clauses = included_clauses(search_state)
    return {} if search_state.query_param.blank? && clauses.empty?

    params = {
      "hl" => true,
      "hl.method" => "unified",
      "hl.snippets" => 1,
      "hl.fragsize" => FRAGMENT_SIZE,
      "hl.tag.pre" => OPEN,
      "hl.tag.post" => CLOSE,
      "hl.encoder" => "html"
    }
    if clauses.any?
      add_clause_parameters(params, clauses)
    else
      scope = SEARCH_FIELD_SCOPE[search_state.params[:search_field].to_s]
      params["hl.fl"] = (scope || FIELDS.keys).join(",")
      params["hl.requireFieldMatch"] = true if scope # the search looked in these fields only
    end
    params
  end

  # The Advanced search rows that include records (not "Does not contain", "has a value" or "is empty"), as [fields, text] pairs
  def self.included_clauses(search_state)
    AdvancedRules.rules(search_state.clause_params).filter_map do |rule|
      # A "has a value" / "is empty" rule has no words; a rule with a fixed reading is given the words Solr searched for
      text = rule.legacy? ? rule.query.strip : AdvancedRules.words(rule.query).join(" ")
      next if text.empty? || rule.negated? || rule.presence?

      [ SEARCH_FIELD_SCOPE[rule.field] || FIELDS.keys, text ]
    end
  end
  private_class_method :included_clauses

  # A clause search puts its query into Solr's JSON query, which leaves the highlighter nothing to read, so it is given one
  # edismax query per row over that row's fields. The words travel as their own parameters, never inside the query text.
  def self.add_clause_parameters(params, clauses)
    clauses.each_with_index do |(fields, text), index|
      params["hlq#{index}"] = "{!edismax qf='#{fields.join(' ')}' mm=0 v=$hlt#{index}}"
      params["hlt#{index}"] = text
    end
    params["hl.q"] = "{!bool #{clauses.each_index.map { |index| "should=$hlq#{index}" }.join(' ')}}"
    params["hl.fl"] = clauses.flat_map(&:first).uniq.join(",")
    params["hl.requireFieldMatch"] = true
  end
  private_class_method :add_clause_parameters

  # The Match for one record: document is a SolrDocument that came from a search (it knows its response). A record with no
  # highlighting entry (no search words, or a response that has none) gets nil, so the card shows no rationale.
  def self.for(document)
    highlighting = document.response && document.response["highlighting"]
    entry = highlighting.is_a?(Hash) ? highlighting[document.id.to_s] : nil
    entry.nil? ? nil : Match.new(entry)
  end

  # What Solr found in one record. entry: { "title_tsim" => [ "...<mark>word</mark>..." ], ... }
  class Match
    def initialize(entry)
      @entry = entry.to_h.select { |field, snippets| FIELDS.key?(field) && Array(snippets).any?(&:present?) }
    end

    # Solr field names, in the order of FIELDS
    def fields = FIELDS.keys & @entry.keys

    def matched_in?(field) = @entry.key?(field)

    # "Title", "Creator"... in the visitor's language
    def labels = fields.map { |field| I18n.t("nexus_ccs.rationale.fields.#{FIELDS.fetch(field)}") }

    def any? = @entry.any?

    # The words Solr marked, as they are written in the record (longest first, so a phrase wins over its words)
    def terms
      @terms ||= @entry.values.flatten.flat_map { |snippet| snippet.to_s.scan(%r{<mark>(.*?)</mark>}m).flatten }
                       .map { |term| CGI.unescapeHTML(term).strip }.reject { |term| term.length < 2 }.uniq(&:downcase).sort_by { |term| -term.length }
    end

    # The first snippet under the card, from a field the card does not show. Returns safe HTML, or nil.
    def snippet
      field = SNIPPET_FIELDS.find { |name| @entry.key?(name) }
      field && SearchHighlighting.safe_snippet(@entry[field].first)
    end

    # text marked up for the words this match found. text: plain, unescaped record text. Returns safe HTML.
    def mark(text)
      text = text.to_s
      return ERB::Util.html_escape(text) if terms.empty?

      pattern = /(?<![\p{L}\p{N}])(?:#{terms.map { |term| Regexp.escape(term) }.join("|")})(?![\p{L}\p{N}])/i
      pieces = text.split(/(#{pattern.source})/i).map.with_index do |piece, index|
        index.odd? ? "#{OPEN}#{ERB::Util.html_escape(piece)}#{CLOSE}" : ERB::Util.html_escape(piece).to_s
      end
      pieces.join.html_safe # rubocop:disable Rails/OutputSafety -- every piece is escaped above; only our own <mark> tags are added
    end
  end

  # Solr's snippet (HTML-encoded text with <mark> tags) rebuilt so that the only markup in it is <mark>: the text between the
  # tags is decoded and escaped again, so nothing a record contains can become a tag, whatever the encoder did.
  def self.safe_snippet(snippet)
    parts = snippet.to_s.split(MARK_PATTERN).map do |part|
      part.match?(MARK_PATTERN) ? part : ERB::Util.html_escape(CGI.unescapeHTML(part)).to_s
    end
    parts.join.html_safe # rubocop:disable Rails/OutputSafety -- see above
  end
end
