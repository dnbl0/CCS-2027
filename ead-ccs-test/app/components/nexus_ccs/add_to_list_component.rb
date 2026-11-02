# frozen_string_literal: true

module NexusCcs
  # "Add to list" on a record (result cards and the record page, beside Save): a disclosure button that opens a panel
  # of the visitor's lists, each a button that adds the record or, when it is already in the list, removes it, and a
  # field to make a new list with the record in it. The panel is plain forms: without JavaScript it is simply shown
  # (list-menu_controller hides it behind the button). One form per card holds every list's button (the button's
  # formaction picks the list), so a page of cards stays light.
  class AddToListComponent < ViewComponent::Base
    def initialize(document:)
      @document = document
    end

    # Hidden while config.x.saved_records is off (config/application.rb)
    def render? = Rails.configuration.x.saved_records

    attr_reader :document

    def document_id = document.id.to_s

    def panel_id = "add-to-list-#{document_id.parameterize}"

    def title
      helpers.document_presenter(document).heading
    end

    def lists = helpers.menu_lists

    def item_id(list) = helpers.list_item_for(list, document_id)
  end
end
