# frozen_string_literal: true

module NexusCcs
  # The end of a record page: one h2, "More like this", with up to three h3 sub-sections of record cards, one after the other and no tabs
  # (the University design system warns that readers rarely open tabs): Related objects (curated), Similar records (computed, in a lazy
  # frame that fills when it nears the screen, so the page makes the one Solr request it always did) and Recently viewed (compact, only
  # when the visitor has a history). A sub-section with nothing to show is not drawn, and the whole block is not when none can be. The
  # records Related objects shows are left out of Similar.
  class MoreLikeThisComponent < ViewComponent::Base
    def initialize(document:, related:, recent:)
      @document = document
      @related = related
      @recent = recent
    end

    attr_reader :document, :related, :recent

    # Related and Recently viewed are known now; Similar is known when its frame loads, so it is counted as possible when the record may have one
    def render? = related.any? || recent.any? || Discovery.listable?(document)

    def excluded_ids = related.first(NexusCcs::RecordCardsComponent::MAX).map { |found| found.id.to_s }
  end
end
