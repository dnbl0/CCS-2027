# frozen_string_literal: true

module NexusCcs
  # The one header block of a record page: a kicker (object type and collection, plain text), the page's h1, the creator (a link
  # to the maker's browse page where there is one) and date, and the Collection ID with a Copy button (CCS-22). It replaces the
  # dark title band, so the title sits beside the creator and date it belongs to.
  class RecordHeaderComponent < ViewComponent::Base
    def initialize(document:)
      @document = document
    end

    attr_reader :document

    def title = Array(document["title_tsim"]).first.presence || document.id.to_s

    # "Painting · University Art Collection"
    def kicker
      type = Array(document["object_type_ssim"]).first.presence || Array(document["format"]).first.presence
      [ type&.to_s&.upcase_first, Array(document["collection_ssim"]).first.presence ].compact.join(" · ").presence
    end

    # [[name, browse path or nil]], the first two creators
    def creators
      Array(document["creator_ssim"]).map(&:to_s).compact_blank.reject { |name| name == RecordCardComponent::UNKNOWN_MAKER }.first(2).map { |name| [ name, Browse.path_for("makers", name) ] }
    end

    def date = Array(document["production_date_ssim"]).first.presence

    def byline? = creators.any? || date.present?

    # "Grainger Museum Collection, accession number 00.0001, UoM ID emu-umc-400001"
    def identifier = CollectionIdentifier.new(document).to_s
  end
end
