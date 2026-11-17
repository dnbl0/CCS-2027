# frozen_string_literal: true

module NexusCcs
  # A section of the Browse page or the home page that holds cards: its heading, the link to the full list beside it, an optional line of
  # introduction, then the content (a NexusCcs::CardLayoutComponent). The page's sections alternate white and light grey (pages/home.css,
  # components/browse.css), so the section draws no background of its own.
  class CardSectionComponent < ViewComponent::Base
    # slug: the section's own name, which gives its class (browse-<slug>, explore-<slug>) and its heading's id
    def initialize(slug:, prefix:, heading:, see_all:, see_all_path:, intro: nil)
      @slug = slug
      @prefix = prefix
      @heading = heading
      @see_all = see_all
      @see_all_path = see_all_path
      @intro = intro
    end

    attr_reader :heading, :see_all, :see_all_path, :intro

    def id = "#{@prefix}-#{@slug}"
  end
end
