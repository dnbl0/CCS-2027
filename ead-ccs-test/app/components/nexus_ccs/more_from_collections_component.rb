# frozen_string_literal: true

module NexusCcs
  # "You may be interested in" on the record page, as the design system's tabs: at most five, each named in a word or two (the design
  # system's guidance: two to five tabs, short titles). Similar (SimilarRecords), then a tab per way the record can be matched
  # (SimilarRows: the same maker, period, place and type). Each panel keeps its full name as its heading ("More by Grainger, Percy"),
  # for screen readers and for the page without JavaScript, and is a lazy Turbo frame of three result cards and See all (SimilarController
  # ?row=), loaded once its tab is shown; a panel whose answer is empty says so. Similar colours (LooksSimilar) is a second part of the
  # Similar panel, under its own heading, when the record has an image to compare (a sixth tab would break the design system's limit).
  # Nothing for a record that may not have recommendations beside it.
  class MoreFromCollectionsComponent < ViewComponent::Base
    Row = Struct.new(:key, :tab, :label, :source)
    TAB_KEYS = { "creator" => "maker", "period" => "period", "place" => "place", "type" => "type" }.freeze

    def initialize(document:)
      @document = document
    end

    def render? = Discovery.listable?(@document) && rows.any?

    def rows
      @rows ||= [ Row.new("similar", t("nexus_ccs.record_page.layout.tabs.similar"), t("nexus_ccs.record_page.layout.similar"),
                          helpers.similar_path(@document.id, view: "tab")) ] +
                SimilarRows.keys_for(@document).map do |key|
                  Row.new(key, t("nexus_ccs.record_page.layout.tabs.#{TAB_KEYS.fetch(key, key)}", default: label(key)), label(key),
                          helpers.similar_path(@document.id, row: key))
                end
    end

    # Similar colours, in the Similar panel, when the record has an image to compare
    def looks_similar_path = (helpers.looks_similar_path(@document.id) if LooksSimilar.eligible?(@document))

    private

    def label(key)
      return t("nexus_ccs.record_page.split.more.row.#{key}") unless key == "creator"

      name = SimilarRows.new(@document, key).described.first
      name ? t("nexus_ccs.record_page.split.more.row.creator", name: name) : t("nexus_ccs.record_page.split.more.row.creator_unnamed")
    end
  end
end
