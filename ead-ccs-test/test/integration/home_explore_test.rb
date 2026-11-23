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

  test "the home page's sections: the museums in justified rows, record types, places and periods, each linking to its records" do
    Rails.cache.write(ExploreEntryPoints::CACHE_KEY, COUNTS, expires_in: 1.day)

    get "/"

    assert_response :success
    assert_select "section[aria-labelledby=explore-title] h2#explore-title", text: "Explore the collections"
    assert_select "section.explore ul.justified > li.justified__item", count: 5
    assert_select "section.explore li.justified__item--lead:first-child h3", text: "University Art Collection"
    assert_select "section.explore-kinds article.result-card h3 a[href*='f_inclusive%5Bclassification_ssim%5D%5B%5D=prints']", text: "Prints and drawings"
    assert_select "section.home-places a.place-row[href*='f%5Bproduction_place_ssim%5D%5B%5D=Japan']"
    assert_select "section.explore-periods article.result-card h3 a[href*='range%5Bdate_start_isi%5D%5Bbegin%5D=1900'][href*='range%5Bdate_start_isi%5D%5Bend%5D=1999']", text: "1900s"
  end

  test "every way in opens all the matching records, not only those with images" do
    Rails.cache.write(ExploreEntryPoints::CACHE_KEY, COUNTS, expires_in: 1.day)

    get "/"

    assert_select "section.explore-kinds a[href*='any_assets=1'], section.home-places a.place-row[href*='any_assets=1'], section.explore-periods a[href*='any_assets=1']", minimum: 3
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
