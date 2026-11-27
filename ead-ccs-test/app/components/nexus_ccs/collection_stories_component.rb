# frozen_string_literal: true

module NexusCcs
  # "Stories from the collection" on a record page (CollectionStories): articles the collection's own website has published about
  # this object. After the National Gallery of Art's article listings (nga.gov/stories/articles):
  #
  # - one story is a wide row between two rules: the source site, then the "Article" kicker, the headline (an h3) and the summary,
  #   with the picture beside them;
  # - two or more are a card grid (two columns for two, three for more): the picture, the kicker, the headline and the summary.
  #
  # The headline is the link of the whole story (stretched, so there is no nested link), to the story's page on this site
  # (/stories/<slug>), which credits and links the site that first published it. Drawn only when the record has a story; no count is shown.
  #
  # The picture is the story's own, loaded by the visitor's browser from the collection's site; else the record's own picture of the
  # object. The collection's site may refuse its picture (a Cloudflare check), so story_image_controller.js then tries the record's
  # picture and, failing that, makes it a text story. Pictures are shown whole, never cropped. The record cards' image rule holds: a
  # record the visitor may not view, or a sensitive one, gets text stories and no picture of the object anywhere in the markup.
  class CollectionStoriesComponent < ViewComponent::Base
    def initialize(stories:, document: nil)
      @stories = stories
      @document = document
    end

    attr_reader :stories

    def render? = stories.any?

    def feature? = stories.one?

    # Two stories fill two columns; three or more, three
    def columns = stories.size == 2 ? 2 : 3

    # The picture shown first: the story's own, else the record's
    def image_url(story)
      return unless pictures?

      story.image_url.presence || record_image_url
    end

    # The picture tried when the story's own will not load (none when the record's is already the one shown)
    def fallback_url(story)
      record_image_url if pictures? && story.image_url.present?
    end

    # One story, drawn by CollectionStoryComponent with the picture this component chose for it
    def story_component(story)
      CollectionStoryComponent.new(story: story, layout: feature? ? :feature : :card, picture: image_url(story), fallback: fallback_url(story))
    end

    private

    def pictures?
      return @pictures if defined?(@pictures)

      @pictures = @document.nil? || (AccessPolicy.view?(@document) && !Sensitivity.sensitive?(@document))
    end

    def record_image_url
      return @record_image_url if defined?(@record_image_url)

      @record_image_url = (AssetVersion.url(@document["thumbnail_path_ssi"].presence) if @document)
    end
  end
end
