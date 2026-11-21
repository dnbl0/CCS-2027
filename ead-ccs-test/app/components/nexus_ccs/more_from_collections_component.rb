# frozen_string_literal: true

module NexusCcs
  # "You may be interested in" (the National Gallery of Art's artwork pages): Similar objects (SimilarRecords), then a tab per way the
  # record can be matched (SimilarRows:
  # by its maker, from the same period, the same place, of the same type; and Looks similar, by colour, when the record has an image
  # to compare). Each panel is a lazy Turbo frame of three result cards and its See all link (SimilarController ?row= /
  # LooksSimilarController), loaded once its tab is shown; a panel whose answer is empty says so. Nothing for a record that may not
  # have recommendations beside it.
  class MoreFromCollectionsComponent < ViewComponent::Base
    Row = Struct.new(:key, :label, :source)
    def initialize(document:)
      @document = document
    end

    def render? = Discovery.listable?(@document) && rows.any?

    def rows
      @rows ||= begin
        list = [ Row.new("similar", t("nexus_ccs.record_page.nga.similar"), helpers.similar_path(@document.id, view: "tab")) ]
        list += SimilarRows.keys_for(@document).map do |key|
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
