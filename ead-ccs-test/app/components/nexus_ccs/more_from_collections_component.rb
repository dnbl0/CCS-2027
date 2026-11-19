# frozen_string_literal: true

module NexusCcs
  # "More from the collections" (approved split layout): one tab per way the record can be matched (SimilarRows: by its maker, from
  # the same period, the same place, of the same type; and Looks similar, by colour, when the record has an image to compare), each
  # panel a lazy Turbo frame of three result cards and its See all link (SimilarController ?row= / LooksSimilarController).
  # A panel loads when it is first shown, so the page makes no request for a tab nobody opens; a tab whose answer is empty says so.
  # Behaviour: controllers/record_tabs_controller.js (ARIA tabs: arrow keys, Home and End). Without JavaScript every panel is
  # shown, one under the other. Nothing for a record that may not have recommendations beside it.
  class MoreFromCollectionsComponent < ViewComponent::Base
    Tab = Struct.new(:key, :label, :source)

    def initialize(document:)
      @document = document
    end

    def render? = Discovery.listable?(@document) && tabs.any?

    def tabs
      @tabs ||= begin
        list = SimilarRows.keys_for(@document).map do |key|
          Tab.new(key, label(key), helpers.similar_path(@document.id, row: key))
        end
        list << Tab.new("colours", t("colours.looks_similar.heading"), helpers.looks_similar_path(@document.id)) if LooksSimilar.eligible?(@document)
        list
      end
    end

    private

    def label(key)
      return t("nexus_ccs.record_page.split.more.tab.#{key}") unless key == "creator"

      name = SimilarRows.new(@document, key).described.first
      name ? t("nexus_ccs.record_page.split.more.tab.creator", name: name) : t("nexus_ccs.record_page.split.more.tab.creator_unnamed")
    end
  end
end
