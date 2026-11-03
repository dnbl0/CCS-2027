# frozen_string_literal: true

module AdvancedRules
  # Included in SearchBuilder after Blacklight's own behaviour: reads the rules of the Advanced search form into Solr's JSON query.
  # A row with no `match` (every link made before rules existed) goes through Blacklight's own code, unchanged.
  module SearchBuilderClauses
    # Blacklight's add_adv_search_clauses, with two differences: a rule that asks for no term ("has a value", "is empty") counts
    # as a rule, and a rule with a fixed reading is turned into its query by AdvancedRules.
    def add_adv_search_clauses(solr_parameters)
      rules = AdvancedRules.rules(search_state.clause_params).select(&:active?)
      return if rules.empty?

      solr_parameters[:defType] = "lucene"
      solr_parameters[:spellcheck] = "false" # spellcheck does not work with the JSON query DSL

      default_op = search_state.query_boolean_operator&.to_sym || :must
      default_op = :must unless %i[must should].include?(default_op)

      rules.each do |rule|
        op, query = rule.legacy? ? adv_search_clause(clause_of(rule), default_op) : AdvancedRules.solr_clause(rule, field_config_for(rule), rule_op(rule, default_op))
        solr_parameters.append_boolean_query(op, query) if query && %i[must must_not should].include?(op&.to_sym)
      end
    end

    private

    # A row's own op (clause[N][op]) wins over the form's menu, as in Blacklight; anything but must / should is ignored
    def rule_op(rule, default_op) = %w[must should].include?(rule.op) ? rule.op.to_sym : default_op

    def field_config_for(rule)
      field = (blacklight_config.search_fields || {})[rule.field]
      field if field&.clause_params
    end

    def clause_of(rule) = { field: rule.field, query: rule.query, op: rule.op }.compact_blank.with_indifferent_access
  end
end
