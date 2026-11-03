# frozen_string_literal: true

# The rules of the Advanced search form. A rule is one row: a field (the search fields), a match (how the term is read) and a term.
# It travels in the address as Blacklight's own clause parameter, so every old link keeps working:
#
#   clause[N][field]  title, creator, subject, description, all_fields
#   clause[N][query]  the term
#   clause[N][op]     must / should / must_not (Blacklight's; the form's "match all / any" menu is the default for a row)
#   clause[N][match]  NEW: how the term is read. Blank (or "contains") is what a row has always been: the term goes to Solr as
#                     the visitor typed it, so the search tips (AND, OR, NOT, quotes, + and -) apply. The others are fixed
#                     readings, which never let the term be read as syntax:
#     all      contains all of these words     every word is required
#     phrase   contains this exact phrase      the words together, in that order
#     begins   begins with                     the whole value starts with the term (title, creator, subject only)
#     not      does not contain these words    a record with any of the words is left out (same as op=must_not)
#     present  has a value                     the field is not blank (no term; not for "all fields")
#     empty    is empty                        the field is blank (no term; not for "all fields")
#
# How rules combine: the form's "match all / any" menu (op) joins the rules that include records (AND / OR); "does not contain"
# rules always leave records out, whichever is chosen, so no mix of AND and OR is ever ambiguous. (The alternative, an AND / OR / NOT
# connector on each row, needs a precedence rule that visitors cannot see; Europeana's query builder has one connector per rule.)
#
# This module reads the parameters and says what each rule means in Solr's JSON query DSL (SearchBuilder uses it through
# AdvancedRules::SearchBuilderClauses). Words are only ever sent inside quotes, with Solr's special characters taken out, or as
# a JSON value of a prefix query: a term cannot reach Solr as syntax in any match but "contains".
module AdvancedRules
  MAX_EXTRA_ROWS = 8 # rows the form adds beyond one per search field
  MAX_RULES = 13     # rules the search will read (the five fields and eight more): the rest are ignored
  MAX_TERM_LENGTH = 255
  MATCHES = %w[contains all phrase begins not present empty].freeze
  PRESENCE = %w[present empty].freeze

  # The stored text field that says whether a record has a value for a search field
  PRESENCE_FIELD = { "title" => "title_tsim", "creator" => "creator_tsim", "subject" => "subject_tsim", "description" => "description_tsim" }.freeze
  # The string field "begins with" reads (the text fields are split into words, so they cannot say where a value starts)
  PREFIX_FIELD = { "title" => "title_si", "creator" => "creator_ssim", "subject" => "subject_ssim" }.freeze

  # Characters kept in a fixed-reading term: letters, marks, digits, spaces and the few that real titles and names have
  TERM_CHARACTERS = /[^\p{L}\p{M}\p{N}\s'’.,&-]/

  Rule = Data.define(:key, :field, :match, :op, :query) do
    def legacy? = match == "contains"
    def presence? = PRESENCE.include?(match)
    def negated? = match == "not" || op == "must_not"

    # Whether the rule asks for anything: a term, or a presence test
    def active? = presence? || query.present?
  end

  # The rules in a request's clause parameter (a Hash, a HashWithIndifferentAccess or ActionController::Parameters), in order
  def self.rules(clause_params)
    pairs = clause_params.respond_to?(:to_unsafe_h) ? clause_params.to_unsafe_h : clause_params
    return [] unless pairs.respond_to?(:each_pair)

    pairs.each_pair.filter_map do |key, clause|
      next unless clause.respond_to?(:[]) && !clause.is_a?(String)

      field = clause[:field] || clause["field"]
      next if field.blank?

      Rule.new(key.to_s, field.to_s, match_of(clause, field.to_s), (clause[:op] || clause["op"]).to_s.presence, (clause[:query] || clause["query"]).to_s)
    end.first(MAX_RULES)
  end

  # What the Advanced search form shows. One fixed row for each search field (the first rule that names it fills it); every other
  # rule is an extra row, in order, at most MAX_EXTRA_ROWS. add: the visitor asked, without JavaScript, for one more blank row;
  # remove: the key of an extra row to leave out. fields: the search field keys, in the order of the form.
  Layout = Data.define(:fixed, :extras)

  def self.layout(clause_params, fields, add: false, remove: nil)
    remaining = rules(clause_params)
    fixed = fields.index_with do |field|
      index = remaining.index { |rule| rule.field == field }
      index && remaining.delete_at(index)
    end
    remaining = remaining.reject { |rule| remove.present? && rule.key == remove.to_s }.first(MAX_EXTRA_ROWS) # a fixed row is never removed
    remaining += [ Rule.new("new", fields.first, "contains", nil, "") ] if add && remaining.size < MAX_EXTRA_ROWS
    Layout.new(fixed, remaining)
  end

  # The matches a field offers, in the order of the menu
  def self.matches_for(field)
    list = %w[contains all phrase not]
    list.insert(3, "begins") if PREFIX_FIELD.key?(field.to_s)
    list.concat(PRESENCE) if PRESENCE_FIELD.key?(field.to_s)
    list
  end

  # A match this field does not offer (a hand-edited address) is read as "all of these words": the safe reading
  def self.match_of(clause, field)
    given = (clause[:match] || clause["match"]).to_s
    return "contains" if given.blank? || given == "contains"

    matches_for(field).include?(given) ? given : "all"
  end
  private_class_method :match_of

  # The words of a term, ready to be quoted: special characters become spaces, so nothing is left that Solr reads as syntax
  def self.words(text)
    text.to_s.first(MAX_TERM_LENGTH).gsub(TERM_CHARACTERS, " ").split.select { |word| word.match?(/[\p{L}\p{N}]/) }
  end

  # The term as one value to match the start of (case is the visitor's: the stored value is compared as written)
  def self.prefix_text(text) = words(text).join(" ")

  # The spellings of a start worth trying: as typed, first letter capital, all lower case, each word capitalised
  def self.prefix_variants(text)
    text = prefix_text(text)
    return [] if text.empty?

    [ text, text[0].upcase + text[1..], text.downcase, text.gsub(/\b\p{Ll}/, &:upcase) ].uniq
  end

  # [ bool operator (:must, :should, :must_not), query for the JSON query DSL ] for one rule, or nil when it asks for nothing
  # field_config: the Blacklight search field (its clause_params carry the edismax settings); default_op: :must or :should
  def self.solr_clause(rule, field_config, default_op)
    return unless rule.active? && field_config

    op, query = case rule.match
    when "all" then [ default_op, edismax(field_config, words(rule.query).map { |word| %(+"#{word}") }.join(" ")) ]
    when "phrase" then [ default_op, edismax(field_config, (phrase = words(rule.query).join(" ")).empty? ? nil : %("#{phrase}")) ]
    when "not" then [ :must_not, edismax(field_config, words(rule.query).map { |word| %("#{word}") }.join(" "), mm: "1") ]
    when "begins" then [ default_op, begins_with(rule) ]
    when "present" then [ default_op, lucene("#{PRESENCE_FIELD.fetch(rule.field)}:[* TO *]") ]
    when "empty" then [ default_op, lucene("*:* -#{PRESENCE_FIELD.fetch(rule.field)}:[* TO *]") ]
    end
    [ op, query ] if query
  end

  def self.edismax(field_config, text, **extra)
    return if text.blank?

    field_config.clause_params.transform_values { |settings| settings.merge(query: text, **extra) }
  end
  private_class_method :edismax

  def self.begins_with(rule)
    variants = prefix_variants(rule.query)
    return if variants.empty?

    { bool: { should: variants.map { |variant| { prefix: { f: PREFIX_FIELD.fetch(rule.field), v: variant } } } } }
  end
  private_class_method :begins_with

  def self.lucene(text) = { lucene: { query: text } }
  private_class_method :lucene

  # How the rule reads in words, for the constraint pill, the diagnostics panel and saved search names:
  # 'does not contain “skull”', 'has a value', 'begins with “Ann”'
  def self.describe(rule)
    key = rule.legacy? && rule.op == "must_not" ? "not" : rule.match
    quoted = rule.query.to_s.squish
    I18n.t("nexus_ccs.advanced_rules.reading.#{key}", term: quoted, default: quoted)
  end
end
