# frozen_string_literal: true

module NexusCcs
  # One section of the home page (the homepage redesign, 2026-11): the heading and its line of introduction on the left, the link to
  # everything of its kind on the right (under them on a phone), then the section's cards (the content). The page's sections alternate
  # white and grey (pages/home.css); the Time section is the one navy band.
  class HomeSectionComponent < ViewComponent::Base
    # tint: a colour for the section's band (a CSS colour or custom property), in place of the white and grey alternation
    def initialize(id:, heading:, intro: nil, link: nil, link_path: nil, extra_class: nil, tint: nil)
      @tint = tint
      @id = id
      @heading = heading
      @intro = intro
      @link = link
      @link_path = link_path
      @extra_class = extra_class
    end

    attr_reader :id, :heading, :intro, :link, :link_path, :extra_class, :tint

    def link? = link.present? && link_path.present?
  end
end
