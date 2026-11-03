# frozen_string_literal: true

module NexusCcs
  # One rule of the Advanced search form. A fixed row names its field in the label of the words box (so "Title" labels the words
  # for the title); an extra row is a group with a menu for the field. Both have the "how to match" menu. The names are Blacklight's
  # clause parameters, plus clause[N][match] (AdvancedRules).
  class AdvancedRuleRowComponent < Blacklight::Component
    # rule: AdvancedRules::Rule; number: the extra row's number (nil for a fixed row); field_label: the field's name for a fixed row
    # field_options / match_options: the options of the menus, as option_groups; focus: the row is new, so its first control is focused
    def initialize(rule:, field_options:, match_options:, field_label: nil, number: nil, focus: false)
      @rule = rule
      @field_options = field_options
      @match_options = match_options
      @field_label = field_label
      @number = number
      @focus = focus
    end

    attr_reader :rule, :number, :field_label

    def extra? = !number.nil?

    def key = rule.key

    def name(part) = "clause[#{key}][#{part}]"

    def dom_id(part) = "advanced-rule-#{key}-#{part}"

    def legend = number && t("nexus_ccs.advanced_rules.extra_title", number: number)

    def term_disabled? = rule.presence?

    def match_label = field_label ? t("nexus_ccs.advanced_rules.match_label", field: field_label) : t("nexus_ccs.advanced_rules.match_menu_label")

    def term_label = field_label || t("nexus_ccs.advanced_rules.term_label")

    def selected_match = rule.match
  end
end
