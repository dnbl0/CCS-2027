# frozen_string_literal: true

module NexusCcs
  # One story on /stories (Stories), after the British Museum's blog listing: the picture, a line with the story's category and date,
  # the headline (the card's one link, stretched over the card), the summary and "Read more". lead: the first story, drawn large.
  #
  # The picture is the story's own, else the picture of the first record it is about (document). A collection's website may
  # refuse its picture, so story_image_controller.js then tries the record's and, failing that, drops the picture. Pictures are
  # shown whole, never cropped. A record the visitor may not view, or a sensitive one, gives no picture at all.
  class StoryCardComponent < ViewComponent::Base
    def initialize(story:, document: nil, lead: false)
      @story = story
      @document = document
      @lead = lead
    end

    attr_reader :story

    def lead? = @lead

    def picture = pictures? ? story.image&.url || record_picture : nil

    # Tried when the story's own picture will not load
    def fallback = (record_picture if pictures? && story.image&.url)

    def kicker
      date = (I18n.l(story.date, format: story.source ? "%B %Y" : "%-d %B %Y") if story.date)
      [ story.category, date ].compact.join(" / ").presence
    end

    def classes = [ "story-card", ("story-card--lead" if lead?), ("story-card--text" unless picture) ].compact.join(" ")

    private

    def pictures?
      @document.nil? || (AccessPolicy.view?(@document) && !Sensitivity.sensitive?(@document))
    end

    def record_picture
      AssetVersion.url(@document["thumbnail_path_ssi"].presence) if @document
    end
  end
end
