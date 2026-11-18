require "test_helper"
require_relative "../../support/geo_fakes"

class Geo::NominatimTest < ActiveSupport::TestCase
  include GeoFakes

  def client(http, slept = [])
    times = [ 0.0, 0.0, 0.2, 0.2 ].each
    Geo::Nominatim.new(http: http, sleeper: ->(seconds) { slept << seconds }, clock: -> { times.next })
  end

  test "sends only the place text, with an application User-Agent and no email address" do
    http = Http.new({ "Melbourne" => [ nominatim_hit(lat: -37.81, lon: 144.96, city: "Melbourne", state: "Victoria", country: "Australia", country_code: "au") ] })
    result = client(http).lookup("Melbourne")

    uri, headers = http.requests.first
    assert_equal "nominatim.openstreetmap.org", uri.host
    assert_equal %w[accept-language addressdetails format limit q], URI.decode_www_form(uri.query).to_h.keys.sort
    assert_match(/CollectionsNavigator/, headers["User-Agent"])
    assert_no_match(/@/, headers["User-Agent"])
    assert_equal [ -37.81, 144.96, "Australia", "AU", "Victoria", "Melbourne", "place" ],
                 result.to_h.values_at(:lat, :lon, :country, :country_code, :state, :locality, :kind)
  end

  test "waits so there is at least a second between requests" do
    slept = []
    nominatim = client(Http.new, slept)
    nominatim.lookup("A")
    nominatim.lookup("B")

    assert_equal 1, slept.size
    assert_in_delta 0.8, slept.first
  end

  test "a place it does not know is nil; a failed request raises" do
    assert_nil client(Http.new).lookup("Nowhere")
    assert_raises(Geo::Error) { client(Http.new(status: 429)).lookup("Melbourne") }
  end

  test "continents, countries and states are their own levels" do
    assert_equal "region", Geo::Nominatim.parse(nominatim_hit(lat: 1, lon: 2, addresstype: "continent", name: "Europe")).kind
    assert_equal "country", Geo::Nominatim.parse(nominatim_hit(lat: 1, lon: 2, addresstype: "country", country: "Australia")).kind
    assert_equal "state", Geo::Nominatim.parse(nominatim_hit(lat: 1, lon: 2, addresstype: "state", state: "Victoria")).kind
  end
end
