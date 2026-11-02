# frozen_string_literal: true

module NexusCcs
  # A record in the list and mosaic views: the CCS UI's "Card image" (with the first digital asset's thumbnail on
  # top) or "Card no media" (without), then the title and three lines: creator, object type, collection.
  # Registered as the list and mosaic views' document_component; everything else is Blacklight's
  # DocumentComponent (title slot with its link and counter, classes, ids).
  class ResultCardComponent < Blacklight::DocumentComponent
    TITLE_TAG = :h5

    # The card's heading is an h5 (Blacklight's default is h3)
    def initialize(**args)
      super(**args, title_component: TITLE_TAG)
    end

    # The card places the Save control itself (below the lines), so the title does not also draw Blacklight's tools
    def before_render
      with_title(actions: false) unless title?
      super
    end

    # Not for a record whose asset is withheld (AccessPolicy :request): its card is the "no media" one
    def media_path
      document["thumbnail_path_ssi"].presence if AccessPolicy.view?(document)
    end

    def media?
      media_path.present?
    end

    def variant
      media? ? "media" : "no-media"
    end

    def card_classes
      classes + [ "result-card", "result-card--#{variant}" ]
    end

    def document_path
      helpers.search_state.url_for_document(document)
    end

    # creator, object type and collection: the first of each, whichever the record has
    def lines
      [ document["creator_ssim"], document["object_type_ssim"], document["collection_ssim"] ].filter_map { |value| Array(value).first.presence }
    end
  end
end
