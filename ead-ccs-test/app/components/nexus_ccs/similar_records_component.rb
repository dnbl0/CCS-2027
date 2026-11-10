# frozen_string_literal: true

module NexusCcs
  # The record page's "Similar records": an empty lazy Turbo frame that fetches /catalog/:id/similar when it nears the screen
  # (SimilarController). Nothing at all for a record that may not have recommendations beside it (its asset is withheld, or it is
  # sensitive): the section is hidden, and the request is never made. The frame stays empty when the answer is "no content".
  class SimilarRecordsComponent < ViewComponent::Base
    def initialize(document:, exclude: [])
      @document = document
      @exclude = exclude
    end

    def render? = Discovery.listable?(@document)

    # exclude: the ids the page lists as Related objects, which Similar leaves out
    def source = helpers.similar_path(@document.id, exclude: @exclude.presence&.join(","))
  end
end
