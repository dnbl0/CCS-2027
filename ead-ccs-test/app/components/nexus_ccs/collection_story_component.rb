# frozen_string_literal: true

module NexusCcs
  # One story in "Stories from the collection" (CollectionStoriesComponent, which chooses its picture): the National Gallery of
  # Art's wide listing row (layout :feature, for a record with one story) or a card of the grid (:card), which is the search
  # results' card (ResultCardComponent's markup and result_card.css). picture: the URL shown first, or nil for a text story;
  # fallback: the URL story_image_controller.js tries when the picture will not load.
  class CollectionStoryComponent < ViewComponent::Base
    LAYOUTS = %i[feature card].freeze

    def initialize(story:, layout:, picture: nil, fallback: nil)
      raise ArgumentError, "layout must be one of #{LAYOUTS.join(', ')}" unless LAYOUTS.include?(layout)

      @story = story
      @layout = layout
      @picture = picture
      @fallback = fallback
    end

    attr_reader :story, :picture, :fallback

    def feature? = @layout == :feature

    def classes
      card = !feature?
      [ ("result-card" if card), ("result-card--media" if card && picture), "collection-story", "collection-story--#{@layout}",
        ("collection-story--text" unless picture) ].compact.join(" ")
    end

    def data = { controller: "story-image", story_image_fallback_value: fallback }.compact
  end
end
