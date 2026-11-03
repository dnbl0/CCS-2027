# frozen_string_literal: true

module NexusCcs
  # The rows of the Advanced search form. A fixed row for each search field (its label, a "how to match" menu, the words), then
  # the extra rules the visitor added (a field menu as well, and Remove), and the "Add another rule" button. With JavaScript
  # (controllers/advanced_rules_controller.js) rows are added and removed in place; without it the same two buttons send the
  # form to the Advanced search page (GET), which draws it again with one more row, or one fewer (add_rule / remove_rule).
  class AdvancedRulesComponent < Blacklight::Component
    # fields: the Blacklight search fields; clause_params: the request's clause parameter
    def initialize(clause_params:, fields:, add: false, remove: nil)
      @fields = fields.index_by(&:key)
      @layout = AdvancedRules.layout(clause_params, @fields.keys, add: add, remove: remove)
      @added = add
    end

    attr_reader :layout

    def max_extra = AdvancedRules::MAX_EXTRA_ROWS

    def extras = layout.extras

    def full? = extras.size >= max_extra

    def field_label(key) = @fields[key]&.display_label("search") || key.humanize

    # The fixed row for each field, in the order of the form
    def fixed_rows
      layout.fixed.each_with_index.map do |(field, rule), index|
        rule ||= AdvancedRules::Rule.new(index.to_s, field, "contains", nil, "")
        [ field, rule.with(key: index.to_s) ]
      end
    end

    # Extra rows are keyed after the fixed ones, so no address can make two rows share a key
    def extra_rows
      extras.each_with_index.map { |rule, index| [ rule.with(key: (@fields.size + index).to_s), index + 1 ] }
    end

    def next_key = @fields.size + extras.size

    def focus_new?(rule) = @added && rule.key.to_s == (@fields.size + extras.size - 1).to_s

    def field_options = @fields.map { |key, field| [ field_label(key), key, { data: { matches: AdvancedRules.matches_for(key).join(" ") } } ] }

    def match_options(field, selected)
      allowed = AdvancedRules.matches_for(field)
      AdvancedRules::MATCHES.map do |match|
        [ t("nexus_ccs.advanced_rules.matches.#{match}"), match, { disabled: allowed.exclude?(match) && match != selected } ]
      end
    end

    def add_path = helpers.advanced_search_catalog_path(anchor: "advanced-rules-add")
  end
end
