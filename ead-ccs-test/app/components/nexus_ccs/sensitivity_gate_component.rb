# frozen_string_literal: true

module NexusCcs
  # Asks the visitor whether to view a sensitive record's digital assets (CCS-227), in place of the image or player, and
  # reminds them of their choice afterwards. Nothing of the asset is on the page until they choose "View this item".
  # Each choice is a form post (SensitivityChoicesController), so it works without JavaScript; the page then reloads with
  # focus on the notice (focus-on-load, when the choice was just made). Not a live region or alert: the visitor's own action
  # reloads the page. The wording is in config/locales/en.yml (nexus_ccs.sensitivity). Which records are sensitive is
  # Sensitivity's rule, not this component's.
  #
  #   :ask       not chosen yet: the notice with "View this item" and "Do not view"
  #   :declined  "Do not view" was chosen: the asset stays hidden, with "View this item" to change their mind
  #   :viewing   "View this item" was chosen: a short reminder, with "Hide this item"
  class SensitivityGateComponent < ViewComponent::Base
    STATES = %i[ask declined viewing].freeze

    def initialize(document:, state:)
      raise ArgumentError, state.inspect unless STATES.include?(state)

      @document = document
      @state = state
    end

    attr_reader :state

    def viewing? = state == :viewing
    def declined? = state == :declined

    def title = t("nexus_ccs.sensitivity.#{state}.title")
    def body = t("nexus_ccs.sensitivity.#{state}.body")

    # The buttons for this state: [[label, choice, css class]]
    def choices
      case state
      when :ask then [ [ t("nexus_ccs.sensitivity.view"), "view", "btn btn-primary" ], [ t("nexus_ccs.sensitivity.do_not_view"), "hide", "btn btn-outline-primary" ] ]
      when :declined then [ [ t("nexus_ccs.sensitivity.view"), "view", "btn btn-primary" ] ]
      else [ [ t("nexus_ccs.sensitivity.hide"), "hide", "btn btn-outline-primary btn-sm" ] ]
      end
    end

    def path = helpers.sensitivity_choice_path(@document.id)

    # Focus goes to the notice when the visitor has just chosen, so they land on the result of their choice
    def focus_on_load? = helpers.flash[:sensitivity_chosen].present?
  end
end
