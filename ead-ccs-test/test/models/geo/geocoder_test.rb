require "test_helper"
require_relative "../../support/geo_fakes"

class Geo::GeocoderTest < ActiveSupport::TestCase
  include GeoFakes

  PIVOT = [
    { "value" => "Melbourne, Victoria, Australia", "count" => 9, "pivot" => [ { "value" => "Oceania", "count" => 9 } ] },
    { "value" => "[Melbourne, Victoria, Australia]", "count" => 1 },
    { "value" => "Atlantis", "count" => 2 },
    { "value" => "Unknown", "count" => 40 }
  ].freeze

  def nominatim(http) = Geo::Nominatim.new(http: http, sleeper: ->(_seconds) { })

  def http
    Http.new({ "Melbourne, Victoria, Australia" => [ nominatim_hit(lat: -37.81, lon: 144.96, city: "Melbourne", state: "Victoria",
                                                                 country: "Australia", country_code: "au") ] })
  end

  test "looks up each place once, keeps not found, copies a second spelling and skips noise" do
    fake = http
    report = Geo::Geocoder.new(solr: Solr.new(pivot: PIVOT), client: nominatim(fake), logger: Logger.new(nil)).run

    assert_equal [ "Atlantis", "Melbourne, Victoria, Australia" ], fake.requests.map { |uri, _| URI.decode_www_form(uri.query).to_h["q"] }.sort
    assert_equal [ 3, 2, 1, 1, 0 ], [ report.places, report.looked_up, report.found, report.not_found, report.failures.size ]
    melbourne = PlaceGeocode.find_by!(place: "Melbourne, Victoria, Australia")
    assert_equal [ "Oceania", "Australia", "Victoria", "Melbourne" ], melbourne.hierarchy
    assert PlaceGeocode.find_by!(place: "Atlantis").not_found
    assert_equal 1, report.copied
    assert_in_delta(-37.81, PlaceGeocode.find_by!(place: "[Melbourne, Victoria, Australia]").lat)
  end

  test "a second run asks nothing: it resumes from what is kept" do
    Geo::Geocoder.new(solr: Solr.new(pivot: PIVOT), client: nominatim(http), logger: Logger.new(nil)).run
    again = http
    report = Geo::Geocoder.new(solr: Solr.new(pivot: PIVOT), client: nominatim(again), logger: Logger.new(nil)).run

    assert_empty again.requests
    assert_equal 3, report.cached
  end

  test "a dry run asks nothing and stores nothing; a failure is reported and asked again next time" do
    report = Geo::Geocoder.new(solr: Solr.new(pivot: PIVOT), client: nominatim(http), logger: Logger.new(nil), dry_run: true).run
    assert_equal 0, PlaceGeocode.count
    assert_includes report.lines.first, "would look up"

    report = Geo::Geocoder.new(solr: Solr.new(pivot: PIVOT), client: nominatim(Http.new(status: 503)), logger: Logger.new(nil)).run
    assert_equal 3, report.failures.size
    assert_equal 0, PlaceGeocode.looked_up.count
  end
end
