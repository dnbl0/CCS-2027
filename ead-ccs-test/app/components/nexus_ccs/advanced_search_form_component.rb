# frozen_string_literal: true

module NexusCcs
  # Blacklight's Advanced search form (its template and filters, unchanged) with the rule builder in place of its plain rows:
  # one fixed row per search field, each with a "how to match" menu, then any extra rules (AdvancedRulesComponent).
  # Used by app/views/catalog/_advanced_search_form.html.erb.
  class AdvancedSearchFormComponent < Blacklight::AdvancedSearchFormComponent
    private

    def initialize_search_field_controls
      with_search_field_control do
        render(NexusCcs::AdvancedRulesComponent.new(
          clause_params: @params[:clause], fields: search_fields.values,
          add: helpers.params[:add_rule].present?, remove: helpers.params[:remove_rule]
        ))
      end
    end
  end
end
