# frozen_string_literal: true

module NexusCcs
  # Places on the home page (the homepage redesign, 2026-11, after Google Arts & Culture's "on this day" collage): a list of places beside
  # a collage of the place pointed at or focused, four of its records each whole at its own shape (place_preview_controller.js). Every
  # place is a link to its records; the collage repeats the list's words, so it is decorative. Without JavaScript the first place is
  # shown. On a narrow screen only the list shows. collages: HomeSections::Collage, one per place.
  class PlacePreviewComponent < ViewComponent::Base
    def initialize(collages:, label:)
      @collages = collages
      @label = label
    end

    attr_reader :collages, :label

    def render? = collages.any?
  end
end
