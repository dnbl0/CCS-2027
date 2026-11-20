# frozen_string_literal: true

module NexusCcs
  # "More from the collections" (approved split layout): one labelled row per way the record can be matched (SimilarRows: by its
  # maker, from the same period, the same place, of the same type; and Looks similar, by colour, when the record has an image to
  # compare), all in view, one under the other, as the museums' record pages do. Each row is a lazy Turbo frame of three result
  # cards and its See all link (SimilarController ?row= / LooksSimilarController), loaded as it nears the screen; a row whose answer
  # is empty says so. On a phone a row's cards scroll sideways. Nothing for a record that may not have recommendations beside it.
  class MoreFromCollectionsComponent < ViewComponent::Base
    Row = Struct.new(:key, :label, :source)
    # Rows shown at first; the others are behind "More ways to explore"
    FIRST_ROWS = 2

    def initialize(document:)
      @document = document
    end

    def render? = Discovery.listable?(@document) && rows.any?

    def rows
      @rows ||= begin
        list = SimilarRows.keys_for(@document).map do |key|
          Row.new(key, label(key), helpers.similar_path(@document.id, row: key))
        end
        list << Row.new("colours", t("colours.looks_similar.heading"), helpers.looks_similar_path(@document.id)) if LooksSimilar.eligible?(@document)
        list
      end
    end

    private

    def label(key)
      return t("nexus_ccs.record_page.split.more.row.#{key}") unless key == "creator"

      name = SimilarRows.new(@document, key).described.first
      name ? t("nexus_ccs.record_page.split.more.row.creator", name: name) : t("nexus_ccs.record_page.split.more.row.creator_unnamed")
    end
  end
end
