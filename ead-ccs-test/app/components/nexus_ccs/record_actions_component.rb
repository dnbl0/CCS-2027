# frozen_string_literal: true

module NexusCcs
  # What a visitor can do with a record, in one row under its title (Figma "Record/Actions", option A): Save, the one main action,
  # as an outlined button; Share as a quiet button; and More, an icon button opening a menu of the rest (Add to list, Cite this
  # record, Copy link). Compare sits under the row when the record has images to compare. Add to list and Cite open their dialogs
  # from the menu (the components render without their own buttons); Copy link copies the record's address and says so. The row
  # keeps to one line down to a 320px phone. Behaviour: controllers/more_actions_controller.js (a menu button: arrow keys, Home,
  # End, Escape returns focus to More). More appears only with JavaScript, since everything in its menu needs it.
  class RecordActionsComponent < ViewComponent::Base
    def initialize(document:)
      @document = document
    end

    attr_reader :document

    def media = @media ||= RecordMedia.for(document, session: helpers.session)
    def tier = media.tier

    def compare? = media.shown? && media.images.any?

    def saved_records? = Rails.configuration.x.saved_records

    def key = document.id.to_s.parameterize
    def menu_id = "more-actions-#{key}"
    def list_dialog_id = "add-to-list-dialog-#{key}"
    def cite_dialog_id = "cite-#{key}" # CiteComponent#dialog_id

    def record_url = helpers.solr_document_url(document)

    def icon(name) = Glyphs.icon(name, size: 24)
  end
end
