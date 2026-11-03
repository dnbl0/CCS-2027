# frozen_string_literal: true

module AdvancedRules
  # Prepended to Blacklight::ClausePresenter (config/initializers/advanced_rules.rb): the pill of an Advanced search row says how the
  # row is read, 'Title  does not contain “skull”', on the results page and in search history. A row as it has always been shows its words.
  module ClausePresenterReading
    def label
      rule = AdvancedRules.rules({ key => user_parameters }).first
      rule ? AdvancedRules.describe(rule) : super
    end
  end
end
