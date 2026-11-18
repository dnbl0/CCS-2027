require "test_helper"
require_relative "../../support/geo_fakes"
require_relative "../../support/env_override"

class Geo::SolrWriterTest < ActiveSupport::TestCase
  include GeoFakes
  include EnvOverride

  def geocode(place, **attributes)
    PlaceGeocode.new(place: place, normalised: place.downcase, looked_up_at: Time.current, source: "nominatim", **attributes)
  end

  def geocodes
    [ geocode("Melbourne, Victoria, Australia", lat: -37.81, lon: 144.96, country: "Australia", country_code: "AU", state: "Victoria",
                                                locality: "Melbourne", kind: "place", region: "Oceania"),
      geocode("Paris", lat: 48.85, lon: 2.35, country: "France", country_code: "FR", state: "Île-de-France", locality: "Paris", kind: "place"),
      geocode("Europe", lat: 51, lon: 10, kind: "region", region: "Europe") ]
  end

  test "writes the coordinates, country, state and every level of the place hierarchy" do
    solr = Solr.new([ { "id" => "a", "production_place_ssim" => [ "Melbourne, Victoria, Australia", "Atlantis" ] },
                      { "id" => "b", "production_place_ssim" => [ "Paris", "Europe" ] } ])
    assert_equal 2, Geo::SolrWriter.new(solr: solr, logger: Logger.new(nil)).write(geocodes)

    a = solr.docs["a"]
    assert_equal [ "-37.81000,144.96000" ], a["place_latlon_llsim"]
    assert_equal [ "Oceania", "Oceania|Australia", "Oceania|Australia|Victoria", "Oceania|Australia|Victoria|Melbourne" ], a["place_hierarchy_ssim"]
    assert_equal [ "-37.81000,144.96000|Oceania|Australia|Victoria|Melbourne" ], a["place_geo_ssim"]
    b = solr.docs["b"]
    assert_includes b["place_hierarchy_ssim"], "Europe|France|Île-de-France|Paris" # region from the country when the records have none
    assert_equal 1, b["place_geo_ssim"].size, "a continent is a filter level, not a marker"
    assert_equal [ "France" ], b["place_country_ssim"]
  end

  test "only changed records are written, and a record whose place is no longer located is cleared" do
    solr = Solr.new([ { "id" => "a", "production_place_ssim" => [ "Paris" ] } ])
    writer = Geo::SolrWriter.new(solr: solr, logger: Logger.new(nil))
    writer.write(geocodes)
    assert_equal 0, writer.write(geocodes)

    assert_equal 1, writer.write([])
    assert_nil solr.docs["a"]["place_hierarchy_ssim"]
    assert_nil solr.docs["a"]["geo_digest_ssi"]
  end

  test "refuses to run without DAM_SOLR_URL" do
    with_env("DAM_SOLR_URL" => nil) do
      assert_raises(Geo::Error) { Geo::SolrWriter.from_env }
    end
  end
end
