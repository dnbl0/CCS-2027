# frozen_string_literal: true

module NexusCcs
  # "Cite this record" on the record page (CCS-131): a button that opens a dialog with the record's citation in each style
  # (Citation::STYLES), each with its own Copy button (controllers/clipboard_controller.js, which says "Copied" on the
  # button and in a polite status line). The text is built by Citation; this only lays it out. Trigger and dialog are one
  # component, as ViewFullRecordComponent's are, and the dialog is controllers/dialog_controller.js (a native modal <dialog>:
  # focus is trapped inside, Escape closes it and focus returns to the button).
  class CiteComponent < ViewComponent::Base
    def initialize(document:, accessed: Date.current)
      @document = document
      @accessed = accessed
    end

    attr_reader :document, :accessed

    def title = Array(document["title_tsim"]).first.presence || "Untitled"

    def dialog_id = "cite-#{document.id.to_s.parameterize}"

    # [style, label, text] for each style
    def citations
      source = Citation.source_for(document, url: helpers.solr_document_url(document))
      Citation.styles.map { |style| [ style, Citation.label(style), Citation.format(source, style, accessed: accessed) ] }
    end

    # "28 October 2026" for the line saying the date the citations were made
    def accessed_text = Citation.date_text(accessed)
  end
end
