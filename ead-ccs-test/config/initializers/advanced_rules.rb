# frozen_string_literal: true

# The pill of an Advanced search row reads its operator (AdvancedRules::ClausePresenterReading). to_prepare: the class is reloaded in development.
Rails.application.config.to_prepare do
  Blacklight::ClausePresenter.prepend(AdvancedRules::ClausePresenterReading)
end
