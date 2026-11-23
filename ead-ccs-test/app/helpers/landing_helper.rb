# frozen_string_literal: true

# A collection's or named collection's own page (CollectionLandingsController), when the category list knows the value (so the page is
# not a 404); nil otherwise, for the caller to fall back to the search
module LandingHelper
  def landing_path_for(kind, value)
    dimension = Categories.find(kind)
    values = dimension && Categories.values(dimension)
    return nil unless values&.any? { |entry| entry["value"] == value }

    collection_landing_path(kind: kind, slug: Browse::Slug.build(kind, value))
  end
end
