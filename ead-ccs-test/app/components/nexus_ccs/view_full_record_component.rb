# frozen_string_literal: true

module NexusCcs
  # "View full record": the record on its collection's own website, behind a leaving-site dialog (CCS-25).
  # Trigger and dialog are rendered by the same component so the pair can't drift apart.
  #
  # Registered as a Blacklight document action in CatalogController, so it gets built with
  # the same keyword arguments passed to Blacklight::Document::ActionComponent.
  class ViewFullRecordComponent < Blacklight::Component
    # The record in its collection's own browser (CCS-25; the sheet's Source URL, sequence 23): source_url_ss, or source_url_ssi on a
    # harvested record. Only an http(s) address is offered; a record without one has no button (the `if:` guard in CatalogController
    # and render? both ask this).
    SOURCE_FIELDS = %w[source_url_ss source_url_ssi].freeze

    def self.url_for(document)
      SOURCE_FIELDS.lazy.filter_map { |field| Array(document[field]).first.to_s.strip.presence }.find { |url| url.match?(%r{\Ahttps?://}i) }
    end

    def initialize(document:, action: nil, **)
      @document = document
      @action = action
    end

    attr_reader :document

    # Blacklight::Document::ActionsComponent tags each <li> with the action's key,
    # so every component registered as a document action has to answer it.
    delegate :key, to: :@action

    def url
      self.class.url_for(document)
    end

    def render? = url.present?

    # The dialog shows the host, not the full URL as the collection URLs get very large
    def host
      URI.parse(url).host.presence || url
    rescue URI::InvalidURIError
      url
    end

    def source_name
      Array(document["collection_ssim"]).first.presence ||
        t("nexus_ccs.view_full_record.default_source")
    end

    def dialog_title_id
      "leaving-site-title-#{document.id.to_s.parameterize}"
    end
  end
end
