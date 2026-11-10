# frozen_string_literal: true

module NexusCcs
  # The home page's "Explore the collections" section: the University's Sublink menu (Matrix CMS) with images, on a grey band.
  # A Fraunces H2 and a short description, then one group each for object type, place and time: a bold navy H3, an optional example
  # picture, a list of arrow links (the count is the one-line quiet description under each) and a "See all ..." arrow link
  # (ExploreEntryPoints). Renders nothing when there are no groups (Solr down and nothing kept).
  class ExploreComponent < ViewComponent::Base
    def initialize(groups: ExploreEntryPoints.groups)
      @groups = groups
    end

    attr_reader :groups

    HUB_SLUGS = { "object-type" => "object-types", "place" => "places", "time" => "periods" }.freeze

    def render? = groups.any?

    def hub_slug(group) = HUB_SLUGS.fetch(group.id)

    def count_label(count) = "#{helpers.number_with_delimiter(count)} #{'record'.pluralize(count)}"

    def heading_id(group) = "explore-#{group.id}"

    def see_all_label(group) = "See all #{group.id == 'time' ? 'periods' : "#{group.heading.downcase}s"}"

    # Whether the group has an example picture to draw. The picture is the record's thumbnail, so only a record whose asset anyone may
    # download and that is not sensitive is ever given here (ExploreEntryPoints); this is the second lock, not the only one.
    def image?(group) = group.image.present? && group.image.path.to_s.start_with?("/")

    def image_path(group) = AssetVersion.url(group.image.path)

    def image_record_path(group) = helpers.solr_document_path(group.image.id)
  end
end
