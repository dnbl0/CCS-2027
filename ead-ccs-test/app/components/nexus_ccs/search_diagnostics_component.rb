# frozen_string_literal: true

module NexusCcs
  # "Why am I seeing these results?" (CCS-43), under a results page that found nothing or only a few records: a disclosure that
  # says in plain language how the search was read (words, phrases, the search field, Advanced search rows, filters, years, a
  # spelling substitution), what may be holding the results back, and what each filter on its own is hiding, with links that
  # take it off. The counts come from SearchService (ResultsDiagnostics::Response); nothing here names a Solr field or setting.
  # Closed to begin with, so a page of a few results is not pushed down by it.
  class SearchDiagnosticsComponent < ViewComponent::Base
    Clause = Data.define(:field, :op, :query)

    # response: the page's Blacklight response; params: the search state's parameters (string keys);
    # config: the blacklight_config (search and filter names)
    def initialize(response:, params:, config:)
      @response = response
      @params = params.to_h.deep_stringify_keys
      @config = config
    end

    attr_reader :response, :config

    def render? = ResultsDiagnostics.applies?(total: response.total, params: @params)

    def zero? = response.total.zero?

    def query = @params["q"].to_s.strip

    def words = ResultsDiagnostics.words(query)

    def phrases = ResultsDiagnostics.phrases(query)

    # Operators and field names in the query: the way a record matches is the operators', not the usual rule
    def operators? = QuerySyntax.explicit?(query)

    # A search field other than "all fields" the visitor chose (Title, Creator...), or nil
    def search_field_label
      key = @params["search_field"].presence
      return if key.blank? || key == "all_fields"

      config.search_fields[key]&.label
    end

    def clauses
      @clauses ||= AdvancedRules.rules(@params["clause"]).select(&:active?).map do |rule|
        label = config.search_fields[rule.field]&.label || rule.field.humanize
        Clause.new(label, clause_key(rule), rule.presence? ? "" : rule.query)
      end
    end

    # Which sentence (nexus_ccs.diagnostics.clause.*) tells how a rule is read: a fixed reading has its own, an old row says must / should / must_not
    def clause_key(rule)
      return rule.negated? ? "must_not" : rule.match unless rule.legacy?

      (rule.op.presence || @params["op"].presence || "must").to_s
    end

    def clause_text(clause)
      t("nexus_ccs.diagnostics.clause.#{clause.op}", field: clause.field, query: clause.query, default: t("nexus_ccs.diagnostics.clause.must", field: clause.field, query: clause.query))
    end

    # The word count a plain search is held to (1 to 4 words need all of them, and so on)
    def lack
      count = words.size + phrases.size
      row = ResultsDiagnostics.words_needed.find { |from, to, _| count >= from && (to.nil? || count <= to) }
      [ count, row ? row.last : 0 ]
    end

    def spelling
      response.try(:spelling_correction)
    end

    # Every filter and year range on the search, as taken from the removals the service counted, or worked out here when it
    # did not count (a page that is not filtered has none)
    def removals
      @removals ||= response.try(:filter_removals) || ResultsDiagnostics.removals(@params, config.facet_fields)
    end

    def counted? = removals.any? { |removal| removal.total }

    # Removals that would add records, most first
    def helpful
      @helpful ||= removals.select { |removal| removal.total.to_i > response.total }.sort_by { |removal| -removal.total }
    end

    def default_filter_on?
      Array(@params.dig("f", SearchDefaults::DIGITAL_ASSET_FIELD)).include?("with")
    end

    def default_filter_hides?
      removal = removals.find { |item| item.field == SearchDefaults::DIGITAL_ASSET_FIELD }
      default_filter_on? && removal&.total.to_i > response.total
    end

    def remove_path(removal) = helpers.search_action_path(removal.params)

    def tips_path = helpers.advanced_search_catalog_path(anchor: "advanced-search-tips-title")

    def count_text(removal) = t("nexus_ccs.diagnostics.more", count: removal.total - response.total, number: helpers.number_with_delimiter(removal.total - response.total))

    # Reasons the results may be few, in plain words. Each is a key under nexus_ccs.diagnostics.reasons.
    def reasons
      @reasons ||= [].tap do |list|
        list << :default_filter if default_filter_hides?
        list << :filters if removals.size > 1 && zero?
        list << :operators if operators?
        list << :phrase if phrases.any? && !operators?
        list << :many_words if !operators? && lack.first >= 5
        list << :search_field if search_field_label
        list << :clauses if clauses.size > 1
        list << :nothing_obvious if list.empty?
      end.uniq
    end
  end
end
