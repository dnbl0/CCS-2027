require "test_helper"

class Explore::PlacesTest < ActiveSupport::TestCase
  Connection = Struct.new(:fields) do
    def get(_path, params:) = { "facet_counts" => { "facet_fields" => fields.transform_values { |pairs| pairs.flat_map { |k, v| [ k, v ] } } } }
  end

  def places(fields)
    Explore::Places.send(:build, Connection.new(fields))
  end

  test "markers, and regions with their countries and places, from the index's place fields" do
    result = places(
      "place_geo_ssim" => { "-37.81000,144.96000|Oceania|Australia|Victoria|Melbourne" => 10, "-37.80000,144.90000|Oceania|Australia|Victoria|Melbourne" => 2,
                            "48.85000,2.35000|Europe|France|Île-de-France|Paris" => 4, "bad" => 1 },
      "place_hierarchy_ssim" => { "Oceania" => 12, "Oceania|Australia" => 12, "Oceania|Australia|Victoria" => 10, "Europe" => 4, "Europe|France" => 4 }
    )

    assert result.map?
    assert_equal [ [ "Melbourne", 12 ], [ "Paris", 4 ] ], result.markers.map { |marker| [ marker.label, marker.count ] }
    assert_equal [ "Oceania", "Europe" ], result.regions.map(&:label)
    australia = result.regions.first.children.first
    assert_equal [ "Australia", 12 ], [ australia.label, australia.count ]
    assert_equal [ "Melbourne" ], australia.children.map(&:label)
    assert_equal({ "place_hierarchy_ssim" => [ "Oceania|Australia" ] }, australia.search_query[:f])
  end

  test "without coordinates: no map, the regions and the commonest places instead" do
    result = places("region_ssim" => { "Oceania" => 5 }, "production_place_ssim" => { "Melbourne" => 3, "Unknown" => 9 })

    assert_not result.map?
    assert_equal [ "Oceania" ], result.plain_regions.map(&:label)
    assert_equal [ "Melbourne" ], result.top_places.map(&:label)
    assert_equal({ "production_place_ssim" => [ "Melbourne" ] }, result.top_places.first.search_query[:f])
  end
end
