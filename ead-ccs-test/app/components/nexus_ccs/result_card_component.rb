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

    # The card places the Save control itself (below the lines), so the title does not also draw Blacklight's tools. When the
    # search words are in the title they are marked (CCS-39).
    def before_render
      unless title?
        marked = marked_title
        marked ? with_title(actions: false) { marked } : with_title(actions: false)
      end
      super
    end

    # What Solr's highlighter found in this record for this search (SearchHighlighting::Match), or nil
    def match
      return @match if defined?(@match)

      @match = SearchHighlighting.for(document)
    end

    # The title with the matched words in <mark>; nil when the title holds none of them
    def marked_title
      return unless match&.matched_in?("title_tsim")

      marked = match.mark(title_text)
      marked if marked.include?(SearchHighlighting::OPEN)
    end

    # The snippet is a piece of the description and the like, so it is not shown for a record whose description is withheld
    def show_snippet?
      !RobotsPolicy.withheld?(document)
    end

    # The "Select" checkbox is for the results page and the selection page only (CCS-40)
    def selectable?
      helpers.controller_name.in?(%w[catalog selections]) && helpers.action_name == (helpers.controller_name == "catalog" ? "index" : "show")
    end

    def title_text
      CGI.unescapeHTML(presenter.heading.to_s)
    end

    # Not for a record whose asset is withheld (AccessPolicy :request), nor a sensitive one (Sensitivity: the visitor
    # chooses on the record page): its card is the "no media" one
    def media_path
      document["thumbnail_path_ssi"].presence if AccessPolicy.view?(document) && !Sensitivity.sensitive?(document)
    end

    def media?
      media_path.present?
    end

    # The thumbnail's width and height attributes, so the card holds the image's shape while it loads (CCS-71); none if the file cannot be read
    def media_size
      width, height = ImageDimensions.for_path(media_path)
      width ? { width: width, height: height } : {}
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

    # creator, object type and collection: the first of each, whichever the record has, with the Solr field the creator is
    # searched in (the others are filters, not searched)
    def line_fields
      [ [ "creator_tsim", document["creator_ssim"] ], [ nil, document["object_type_ssim"] ], [ nil, document["collection_ssim"] ] ]
        .filter_map { |field, value| [ field, Array(value).first.presence ] if Array(value).first.present? }
    end

    def lines
      line_fields.map(&:last)
    end

    # A line as it is drawn: the creator's has the searched words marked when that is where they matched (CCS-39)
    def line_html(field, value)
      field && match&.matched_in?(field) ? match.mark(value) : value
    end
  end
end
