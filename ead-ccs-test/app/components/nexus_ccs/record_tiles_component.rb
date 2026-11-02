# frozen_string_literal: true

module NexusCcs
  # A titled row of records, each a link with its image (when the visitor may see it), title, object type and collection:
  # the record page's "Related objects" and "Recently viewed". Renders nothing without records. An image is shown under
  # the same rule as the result cards (AccessPolicy, Sensitivity), whole and never cropped (CCS-71: its size is declared).
  class RecordTilesComponent < ViewComponent::Base
    def initialize(id:, heading:, documents:)
      @id = id
      @heading = heading
      @documents = documents
    end

    attr_reader :id, :heading, :documents

    def render? = documents.any?

    def title(document) = Array(document["title_tsim"]).first.presence || document.id

    def meta(document)
      [ Array(document["object_type_ssim"]).first, Array(document["collection_ssim"]).first ].compact_blank.map(&:to_s).map(&:upcase_first).join(" · ")
    end

    def image_path(document)
      document["thumbnail_path_ssi"].presence if AccessPolicy.view?(document) && !Sensitivity.sensitive?(document)
    end

    def image_size(path)
      width, height = ImageDimensions.for_path(path)
      width ? { width: width, height: height } : {}
    end
  end
end
