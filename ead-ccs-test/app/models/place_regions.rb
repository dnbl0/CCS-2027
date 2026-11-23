# frozen_string_literal: true

# The region (continent) of each place, for the Places page's "browse by region" (browse/places): from the places the geocoder found
# (PlaceGeocode, rake geo:geocode): the continent of their country (Geo::Hierarchy::CONTINENTS), else their own region when it names a
# continent (the geocoder's region also holds states and nationalities, which are not offered). Kept for a day. A place it has
# not found has no region (it is still in "All regions"). Empty when the table is not there (the page then offers no regions).
module PlaceRegions
  CACHE_KEY = "place_regions/v2"
  CONTINENTS = Geo::Hierarchy::CONTINENTS.values.uniq.freeze
  # The geocoder's names for parts of the Americas
  AMERICAS = [ "North America", "South America", "North and Central America", "Central America", "Caribbean", "Latin America" ].freeze

  module_function

  # { "melbourne, victoria, australia" => "Oceania", ... }
  def map
    Rails.cache.fetch(CACHE_KEY, expires_in: 1.day) do
      PlaceGeocode.where(not_found: false).pluck(:place, :region, :country_code).each_with_object({}) do |(place, region, code), regions|
        found = Geo::Hierarchy::CONTINENTS[code.to_s.upcase] || continent(region)
        regions[place.to_s.downcase] = found if found
      end
    end
  rescue ActiveRecord::ActiveRecordError
    {}
  end

  def region_of(place) = map[place.to_s.downcase]

  def continent(region)
    return "Americas" if AMERICAS.include?(region)

    region if CONTINENTS.include?(region)
  end

  # The regions of these places, with how many places each, most first: [["Europe", 312], ...]
  def counts(values)
    Array(values).each_with_object(Hash.new(0)) { |(value, _count), tally| (region = region_of(value)) && tally[region] += 1 }
                 .sort_by { |region, count| [ -count, region ] }
  end
end
