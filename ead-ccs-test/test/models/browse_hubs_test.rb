# frozen_string_literal: true

require "test_helper"

class BrowseHubsTest < ActiveSupport::TestCase
  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @cache }

  class FakeConnection
    attr_reader :params, :calls

    def initialize(facets: {}, queries: {}, raise: nil)
      @facets = facets
      @queries = queries
      @raise = raise
      @calls = 0
    end

    def get(_path, params:)
      @params = params
      @calls += 1
      Kernel.raise @raise if @raise

      { "facet_counts" => { "facet_fields" => @facets, "facet_queries" => @queries } }
    end
  end

  test "each way in has a slug, a title and the field it lists; an unknown slug is nil" do
    hub = BrowseHubs.find("object-types")

    assert_equal "object_type_ssim", hub.field
    assert_equal "Object types", hub.title
    assert_nil BrowseHubs.find("nonsense")
    assert_equal %w[object-types places periods makers subjects], BrowseHubs.all.map(&:slug)
  end

  test "the values of a field come with their counts, the most records first, from one request that is then kept" do
    connection = FakeConnection.new(facets: { "object_type_ssim" => [ "harp", 5, "lyre", 9, "bell", 2 ] })
    hub = BrowseHubs.find("object-types")

    2.times { assert_equal [ [ "lyre", 9 ], [ "harp", 5 ], [ "bell", 2 ] ], BrowseHubs.values(hub, connection) }

    assert_equal 1, connection.calls
    assert_equal(-1, connection.params[:"facet.limit"])
    assert_equal 1, connection.params[:"facet.mincount"]
  end

  test "an unknown maker is not listed" do
    connection = FakeConnection.new(facets: { "creator_ssim" => [ "Unknown", 900, "Yamada", 3 ] })

    assert_equal [ [ "Yamada", 3 ] ], BrowseHubs.values(BrowseHubs.find("makers"), connection)
  end

  test "Solr being down gives the last good list, or none, and a failed answer is not kept" do
    hub = BrowseHubs.find("places")
    assert_nil BrowseHubs.values(hub, FakeConnection.new(raise: Errno::ECONNREFUSED))

    BrowseHubs.values(hub, FakeConnection.new(facets: { "production_place_ssim" => [ "Japan", 4 ] }))
    Rails.cache.delete("browse_hubs/v1/places")
    assert_equal [ [ "Japan", 4 ] ], BrowseHubs.values(hub, FakeConnection.new(raise: Errno::ECONNREFUSED))
  end

  test "the letters are those the values start with; a name that starts with a digit or a sign is under #" do
    values = [ [ "Étui", 2 ], [ "apple", 1 ], [ "(unnamed)", 1 ], [ "1973 print", 1 ], [ "Bell", 3 ] ]

    assert_equal %w[A B E #], BrowseHubs.letters(values)
    assert_equal [ [ "Étui", 2 ] ], BrowseHubs.for_letter(values, "E")
    assert_equal [ [ "(unnamed)", 1 ], [ "1973 print", 1 ] ], BrowseHubs.for_letter(values, "#")
    assert_equal [], BrowseHubs.for_letter(values, "Z")
  end

  test "the periods are chronological and leave out the empty ones" do
    first = BrowseHubs.periods(2030).first
    queries = BrowseHubs.periods(2030).to_h { |_label, from, to| [ ExploreEntryPoints.period_query(from, to), 0 ] }
    one = BrowseHubs.periods(2030).find { |label, *| label == "1950–1959" }
    queries[ExploreEntryPoints.period_query(one[1], one[2])] = 12

    result = BrowseHubs.period_values(FakeConnection.new(queries: queries), 2030)

    assert_equal "Before 1000", first.first
    assert_equal [ [ "1950–1959", 12, 1950, 1959 ] ], result
  end

  test "the search a value opens finds all its records, not only those with images" do
    query = BrowseHubs.query("object_type_ssim", "harp")

    assert_equal({ any_assets: "1", f: { "object_type_ssim" => [ "harp" ] }, search_field: "all_fields" }, query)
  end
end
