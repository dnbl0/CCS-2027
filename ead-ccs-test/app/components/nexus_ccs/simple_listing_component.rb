# frozen_string_literal: true

module NexusCcs
  # The University's "simple listing" (museumsandcollections.unimelb.edu.au/collections, simple-listing--four; measured 2026-11-24): four
  # to a row (two on a tablet, one on a phone), 24px apart; each a 16:10 picture filling its frame, 24px, then its title (24px, semibold,
  # the link colour, underlined). The picture is decorative (the title names it); the title's link covers the whole item, so the picture
  # is part of the one target. items: HomeCollections::Item; path: a lambda giving each item's address.
  class SimpleListingComponent < ViewComponent::Base
    def initialize(items:, label:, path:, heading_tag: :h3)
      @items = items
      @label = label
      @path = path
      @heading_tag = heading_tag
    end

    attr_reader :items, :label, :heading_tag

    def path_for(item) = @path.call(item)

    def render? = items.any?
  end
end
