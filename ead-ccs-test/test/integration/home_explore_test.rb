require "test_helper"
require_relative "../support/outages"

# The home page's "Explore by" section: ways into the records that do not need a search term (as Google Arts & Culture and
# Europeana offer). The numbers come from Solr and are kept like the header menu's (ExploreEntryPoints).
class HomeExploreTest < ActionDispatch::IntegrationTest
  include Outages

  COUNTS = {
    "object_type_ssim" => [ [ "lyre", 120 ], [ "photograph", 3400 ] ],
    "production_place_ssim" => [ [ "Japan", 85 ] ],
    "periods" => {
      ExploreEntryPoints.period_key(1900, 1999) => 5000,
      ExploreEntryPoints.period_key(2000, Time.zone.today.year) => 40
    }
  }.freeze

  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @cache }

  test "the home page offers ways in by object type, place and time, each with its record count" do
    Rails.cache.write(ExploreEntryPoints::CACHE_KEY, COUNTS, expires_in: 1.day)

    get "/"

    assert_response :success
    assert_select "section[aria-labelledby=explore-title] h2#explore-title", text: "Explore the collections"
    assert_select "section.explore h3", count: 3
    assert_select "a.explore__link[href*='f%5Bobject_type_ssim%5D%5B%5D=lyre']", text: /Lyre/
    assert_select "a.explore__link[href*='f%5Bobject_type_ssim%5D%5B%5D=lyre'] .explore__count", text: "120 records"
    assert_select "a.explore__link[href*='f%5Bobject_type_ssim%5D%5B%5D=photograph'] .explore__count", text: "3,400 records"
    assert_select "a.explore__link[href*='f%5Bproduction_place_ssim%5D%5B%5D=Japan']"
    assert_select "a.explore__link[href*='range%5Bdate_start_isi%5D%5Bbegin%5D=1900'][href*='range%5Bdate_start_isi%5D%5Bend%5D=1999']", text: /1900–1999/
  end

  test "every way in opens all the matching records, not only those with images" do
    Rails.cache.write(ExploreEntryPoints::CACHE_KEY, COUNTS, expires_in: 1.day)

    get "/"

    assert_select "a.explore__link[href*='any_assets=1']", count: 5
  end

  test "the entry points come from the indexed records: the most common values first, with their real counts" do
    needs_solr
    connection = Blacklight.default_index.connection

    counts = ExploreEntryPoints.counts(connection)
    types = counts[ExploreEntryPoints::OBJECT_TYPE_FIELD]

    assert_equal ExploreEntryPoints::LIMIT, types.size
    assert_equal types.map(&:last).sort.reverse, types.map(&:last)
    value, count = types.first
    in_solr = connection.get("select", params: { q: %(object_type_ssim:"#{value}"), rows: 0 }).dig("response", "numFound")
    assert_equal in_solr, count

    twentieth = ExploreEntryPoints.period_key(1900, 1999)
    in_century = connection.get("select", params: { q: "date_start_isi:[1900 TO 1999]", rows: 0 }).dig("response", "numFound")
    assert_equal in_century, counts["periods"][twentieth]
  end

  test "Solr down and nothing kept: the home page still renders, without the section" do
    with_solr_down do
      get "/"
      assert_response :success
      assert_select "section.explore", count: 0
    end
  end
end
