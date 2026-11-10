require "test_helper"
require_relative "../support/outages"

# The home page's "Explore the collections" section: ways into the records that do not need a search term (as Google Arts & Culture and
# Europeana offer). The numbers come from Solr and are kept like the header menu's (ExploreEntryPoints).
class HomeExploreTest < ActionDispatch::IntegrationTest
  include Outages

  PATH = "/digital-assets/thumbs/0000_013_1_pf.jpg"
  COUNTS = {
    "collections" => [ [ "University Art Collection", 14_537 ], [ "Indigenous Collections", 1540 ] ],
    "kinds" => [ [ "Prints and drawings", 7192, %w[prints drawings] ], [ "Paintings", 2555, [ "paintings" ] ] ],
    "places" => [ [ "Japan", 85 ] ],
    "periods" => { ExploreEntryPoints.period_key(1900, 1999) => 5000, ExploreEntryPoints.period_key(2000, Time.zone.today.year) => 40 }
  }.freeze

  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @cache }

  test "the home page offers a tile for each collection, kinds of records, and places and periods" do
    Rails.cache.write(ExploreEntryPoints::CACHE_KEY, COUNTS, expires_in: 1.day)

    get "/"

    assert_response :success
    assert_select "section[aria-labelledby=explore-title] h2#explore-title", text: "Explore the collections"
    assert_select "a.explore__tile-link[href*='f%5Bcollection_ssim%5D%5B%5D=University+Art+Collection'] .explore__tile-count", text: "14,537 records"
    assert_select "a.explore__tile-link h3", count: 2
    assert_select "a.explore__link[href*='f_inclusive%5Bclassification_ssim%5D%5B%5D=prints']", text: "Prints and drawings"
    assert_select "a.explore__link[href*='f%5Bproduction_place_ssim%5D%5B%5D=Japan']"
    assert_select "a.explore__link[href*='range%5Bdate_start_isi%5D%5Bbegin%5D=1900'][href*='range%5Bdate_start_isi%5D%5Bend%5D=1999']", text: "1900s"
  end

  test "the section has no picture unless one was kept for a tile, and the Indigenous Collections tile never has one" do
    image = { id: "emu-1", title: "A bronze lyre", path: PATH, width: 400, height: 300 }
    Rails.cache.write(ExploreEntryPoints::CACHE_KEY, COUNTS, expires_in: 1.day)
    get "/"
    assert_select "section.explore img", count: 0

    Rails.cache.write(ExploreEntryPoints::CACHE_KEY, COUNTS.merge("images" => { "University Art Collection" => image, "Indigenous Collections" => image }), expires_in: 1.day)
    get "/"
    assert_select "section.explore img[alt=''][loading=lazy][width='400'][height='300']", count: 1
    assert_select "section.explore li.explore__tile:nth-child(1) img", count: 1
    assert_select "section.explore li.explore__tile:nth-child(2) img", count: 0
  end

  test "every way in opens all the matching records, not only those with images" do
    Rails.cache.write(ExploreEntryPoints::CACHE_KEY, COUNTS, expires_in: 1.day)

    get "/"

    assert_select "section.explore a[href*='any_assets=1']", count: 2 + 2 + 1 + 2
  end

  test "the entry points come from the indexed records, with their real counts" do
    needs_solr
    connection = Blacklight.default_index.connection

    counts = ExploreEntryPoints.counts(connection)
    name, count = counts["collections"].first

    in_solr = connection.get("select", params: { q: %(collection_ssim:"#{name}"), rows: 0 }).dig("response", "numFound")
    assert_equal in_solr, count
    assert_not_includes counts["collections"].map(&:first), "[other]"
    label, kind_count, values = counts["kinds"].first
    in_kind = connection.get("select", params: { q: Browse.field_query("classification_ssim", ExploreEntryPoints.kinds.to_h.fetch(label)), rows: 0 }).dig("response", "numFound")
    assert_equal in_kind, kind_count
    assert_not_empty values
  end

  test "Solr down and nothing kept: the home page still renders, without the section" do
    with_solr_down do
      get "/"
      assert_response :success
      assert_select "section.explore", count: 0
    end
  end
end
