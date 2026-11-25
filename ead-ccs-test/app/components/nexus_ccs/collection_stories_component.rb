# frozen_string_literal: true

module NexusCcs
  # "Stories from the collection" on a record page (CollectionStories): short articles the collection's own website has published
  # about this object. The record cards' look (object-cards, RecordCardComponent): an h2, a list of cards, each with its title as an
  # h3 and the link of the whole card (stretched, so there is no nested link), the image whole in the 16:9 frame (never cropped),
  # a short summary and the site it is from. The link goes to the story on that site, in the same tab, as every link on the site does.
  # Drawn only when the record has a story; no count is shown.
  #
  # The image is the story's own picture of the object, loaded by the visitor's browser from the University site. It follows the
  # record cards' image rule: a record the visitor may not view, or a sensitive one, gets text cards (no picture of it is shown).
  class CollectionStoriesComponent < ViewComponent::Base
    def initialize(stories:, document: nil)
      @stories = stories
      @document = document
    end

    attr_reader :stories

    def render? = stories.any?

    def image_url(story)
      story.image_url if pictures?
    end

    def card_classes(story) = [ "object-card", "collection-story", ("object-card--text" unless image_url(story)) ].compact.join(" ")

    private

    def pictures?
      return @pictures if defined?(@pictures)

      @pictures = @document.nil? || (AccessPolicy.view?(@document) && !Sensitivity.sensitive?(@document))
    end
  end
end
