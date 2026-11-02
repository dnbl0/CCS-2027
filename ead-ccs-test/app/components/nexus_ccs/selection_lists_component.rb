# frozen_string_literal: true

module NexusCcs
  # "Add selected to a list" on the selection page (CCS-40): a button for each of the visitor's lists, posting every selected
  # record's id to that list's items (ListItemsController, which adds each once). Needs the guest row the lists hang from, so it
  # is drawn only while saved records are on. With no lists it points to making one.
  class SelectionListsComponent < ViewComponent::Base
    def initialize(documents:)
      @documents = documents
    end

    attr_reader :documents

    def render? = Rails.configuration.x.saved_records && documents.any?

    def lists = helpers.menu_lists
  end
end
