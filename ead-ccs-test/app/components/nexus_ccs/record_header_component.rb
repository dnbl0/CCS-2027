# frozen_string_literal: true

module NexusCcs
  # The header block of a record page: a kicker (object type and collection, plain text), the page's h1, the creator (a link to the
  # maker's browse page where there is one) and date, and one quiet line of place or material. The Collection ID with its Copy
  # button (CCS-22) is in the actions rail (RecordActionsComponent).
  class RecordHeaderComponent < ViewComponent::Base
    def initialize(document:, title_markup: nil)
      @document = document
      @title_markup = title_markup
    end

    attr_reader :document

    def title = Array(document["title_tsim"]).first.presence || document.id.to_s

    # The title with any de-bias finds marked (RecordDebias), else the plain title
    def title_markup = @title_markup || title

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

    # One quiet line under the byline: where it was made, else what it is made of
    def place_line
      Array(document["production_place_ssim"]).map(&:to_s).compact_blank.first(2).join(", ").presence ||
        Array(document["material_ssim"]).map(&:to_s).compact_blank.first(3).join(", ").presence
    end
  end
end
