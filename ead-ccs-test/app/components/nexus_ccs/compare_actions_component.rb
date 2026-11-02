# frozen_string_literal: true

module NexusCcs
  # Under a record's media: "Compare images" (the record's own images side by side) and "Add to compare" (this record to the
  # comparison with others, CCS-58). Shown only when the record's images are on the page, so a withheld or not-yet-chosen sensitive
  # record offers neither; CompareController checks again when the request arrives.
  class CompareActionsComponent < ViewComponent::Base
    def initialize(document:, images:)
      @document = document
      @image_count = images
    end

    attr_reader :document, :image_count

    def render? = image_count.positive?
    def id = document.id.to_s
    def compared_ids = CompareList.new(helpers.session).ids
    def in_comparison? = compared_ids.include?(id)
    def comparison_size = compared_ids.size
    def full? = comparison_size >= CompareList::MAX && !in_comparison?
    def several_images? = image_count > 1
    def title = Array(document["title_tsim"]).first.presence || "Record"
  end
end
