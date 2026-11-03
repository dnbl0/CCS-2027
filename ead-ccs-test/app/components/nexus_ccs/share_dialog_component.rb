# frozen_string_literal: true

module NexusCcs
  # "Share and embed" on a record page, a shared gallery and (as "Share this list") the owner's list page: a button that opens a
  # modal dialog (controllers/dialog_controller.js, as CiteComponent's) holding the link with Copy link and, where the browser has
  # it, the Web Share sheet (controllers/share_controller.js), and the iframe code to embed the page with Copy buttons. Every
  # copy says "Copied" on the button and in a polite status line (controllers/clipboard_controller.js). No third-party script.
  #
  #   kind: :record    document: the record
  #   kind: :gallery   list: the shared list (a visitor's view of it)
  #   kind: :list      list: the owner's list; the block holds the owner's controls (create, change and stop the link), and the
  #                    link and code appear only once the list is shared. open: opens the dialog as the page loads.
  class ShareDialogComponent < ViewComponent::Base
    def initialize(kind:, document: nil, list: nil, open: false)
      @kind = kind
      @document = document
      @list = list
      @open = open
    end

    attr_reader :kind, :document, :list

    def open? = @open

    def dom_id = kind == :record ? "share-#{document.id.to_s.parameterize}" : "share-#{kind}"

    def button_label = t(kind == :list ? "nexus_ccs.share.button_list" : "nexus_ccs.share.button")
    def title = t(kind == :list ? "nexus_ccs.share.title_list" : "nexus_ccs.share.title")

    # What is shared, for the share sheet and the labels
    def subject
      kind == :record ? (Array(document["title_tsim"]).first.presence || "Untitled") : list.name
    end

    # The link to share, or nil (a list not yet shared)
    def share_url
      case kind
      when :record then "#{base_url}#{helpers.solr_document_path(document)}"
      else "#{base_url}#{helpers.gallery_path(list.share_token)}" if list.shared?
      end
    end

    def embed
      return @embed if defined?(@embed)

      @embed =
        if kind == :record
          EmbedCode.for_record(document, src: "#{base_url}#{helpers.embed_record_path(document.id)}")
        elsif list.shared?
          EmbedCode.for_gallery(list, src: "#{base_url}#{helpers.embed_gallery_path(list.share_token)}")
        end
    end

    def preview_path = embed&.src&.delete_prefix(base_url)

    def link_label = t("nexus_ccs.share.link_label_#{kind == :record ? 'record' : 'gallery'}")

    private

    def base_url = BotControls.base_url(helpers.request)
  end
end
