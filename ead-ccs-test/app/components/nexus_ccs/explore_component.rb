# frozen_string_literal: true

module NexusCcs
  # The home page's "Explore by" section: tiles that open records by object type, place and time (ExploreEntryPoints).
  # Renders nothing when there are no groups (Solr down and nothing kept).
  class ExploreComponent < ViewComponent::Base
    def initialize(groups: ExploreEntryPoints.groups)
      @groups = groups
    end

    attr_reader :groups

    def render? = groups.any?

    def count_label(count) = "#{helpers.number_with_delimiter(count)} #{'record'.pluralize(count)}"
  end
end
