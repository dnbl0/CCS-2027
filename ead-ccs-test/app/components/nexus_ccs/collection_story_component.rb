# frozen_string_literal: true

module NexusCcs
  # One story in "Stories from the collection" (CollectionStoriesComponent, which decides its picture): the wide row ("feature") or
  # a card of the grid ("card").
  class CollectionStoryComponent < ViewComponent::Base
    def initialize(story:, variant:, stories:)
      @story = story
      @variant = variant
      @stories = stories
    end

    attr_reader :story, :variant

    def feature? = variant == "feature"

    def classes = @stories.story_classes(story, variant)

    def image_url = @stories.image_url(story)

    def fallback_url = @stories.fallback_url(story)
  end
end
