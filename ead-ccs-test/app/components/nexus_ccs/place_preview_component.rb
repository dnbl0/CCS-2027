# frozen_string_literal: true

module NexusCcs
  # Places on the home page, after Google Arts & Culture's place pages (looked at 2026-11-23, described in our own words): a row of
  # places, each a tab with a picture, its name and its number of records; the chosen place's spotlight shows its name, what it holds,
  # the way to all its records, and a "Discover this place" wall of its records (each a link to its record page) in the fluid mosaic.
  # Tabs (place_tabs_controller.js): arrow keys move between them, Home and End go to the ends. Without JavaScript every place's spotlight
  # shows, one after another. collages: HomeSections::Collage, one per place.
  class PlacePreviewComponent < ViewComponent::Base
    def initialize(collages:, label:)
      @collages = collages
      @label = label
    end

    attr_reader :collages, :label

    def render? = collages.any?

    def id(kind, index) = "place-#{kind}-#{index}"
  end
end
