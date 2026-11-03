# frozen_string_literal: true

require "test_helper"

# The pages behind the home page's Explore tiles: every object type, place, period, maker and subject, each opening its records.
class BrowsePagesTest < ActionDispatch::IntegrationTest
  VALUES = [ [ "lyre", 120 ], [ "harp", 40 ], [ "bell", 3 ], [ "Étui", 1 ], [ "1973 print", 1 ] ].freeze

  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @cache }

  def seed(slug, values) = Rails.cache.write("browse_hubs/v1/#{slug}", values, expires_in: 1.day)

  test "the browse page lists every way in, each with its page" do
    get "/browse"

    assert_response :success
    assert_select "h1", "Browse the collections"
    BrowseHubs.all.each { |hub| assert_select "main a[href='/browse/#{hub.slug}']", text: /#{hub.title}/ }
  end

  test "a way in lists the most common values first, each opening all its records with its count" do
    seed("object-types", VALUES)

    get "/browse/object-types"

    assert_response :success
    assert_select "h1", "Browse object types"
    links = css_select("a.browse__link").map { |a| a.text.squish }
    assert_equal [ "Lyre 120 records", "Harp 40 records", "Bell 3 records", "Étui 1 record", "1973 print 1 record" ], links
    assert_select "a.browse__link[href*='f%5Bobject_type_ssim%5D%5B%5D=lyre'][href*='any_assets=1']"
  end

  test "a letter shows the values that start with it, alphabetically, and says which letter it is" do
    seed("object-types", VALUES)

    get "/browse/object-types", params: { letter: "B" }

    assert_select "a.browse__link", count: 1
    assert_select "a.browse__link", text: /Bell/
    assert_select "nav[aria-label='Browse by letter'] a[aria-current='page']", text: "B"
    assert_select "nav[aria-label='Browse by letter'] a", text: "Z", count: 0 # only letters that have records
  end

  test "a letter that does not exist is the default list, not an error" do
    seed("object-types", VALUES)

    get "/browse/object-types", params: { letter: "<script>" }

    assert_response :success
    assert_select "a.browse__link", count: 5
  end

  test "the periods page lists the periods in order, from Before 1000 to now" do
    Rails.cache.write("browse_hubs/v1/periods", [ [ "Before 1000", 2, -10_000, 999 ], [ "1950–1959", 12, 1950, 1959 ] ], expires_in: 1.day)

    get "/browse/periods"

    assert_response :success
    assert_equal [ "Before 1000 2 records", "1950–1959 12 records" ], css_select("a.browse__link").map { |a| a.text.squish }
    assert_select "a.browse__link[href*='range%5Bdate_start_isi%5D%5Bbegin%5D=1950'][href*='range%5Bdate_start_isi%5D%5Bend%5D=1959']"
  end

  test "an unknown way in is not found" do
    get "/browse/nonsense"

    assert_response :not_found
  end

  test "with Solr down and nothing kept the page says so, instead of failing" do
    original = SolrGuard.method(:run)
    SolrGuard.define_singleton_method(:run) { |*| raise Errno::ECONNREFUSED }
    begin
      get "/browse/places"
    ensure
      SolrGuard.define_singleton_method(:run, original)
    end

    assert_response :service_unavailable
    assert_select "h1", "Browse places"
    assert_select ".browse__unavailable"
  end

  test "the home page's Explore groups link to their full lists" do
    Rails.cache.write(ExploreEntryPoints::CACHE_KEY, { "object_type_ssim" => [ [ "lyre", 1 ] ], "production_place_ssim" => [ [ "Japan", 1 ] ], "periods" => { ExploreEntryPoints.period_key(1900, 1999) => 1 } }, expires_in: 1.day)

    get "/"

    assert_select "section.explore a.explore__all[href='/browse/object-types']"
    assert_select "section.explore a.explore__all[href='/browse/places']"
    assert_select "section.explore a.explore__all[href='/browse/periods']"
  end
end
