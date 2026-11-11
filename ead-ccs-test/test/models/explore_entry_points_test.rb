# frozen_string_literal: true

require "test_helper"

# The curated groups of the home page's Explore section (config/explore_kinds.yml): what is kept from Solr, and what is drawn from it
class ExploreEntryPointsTest < ActiveSupport::TestCase
  def kind_query(label)
    ExploreEntryPoints.kinds.find { |name, _values| name == label }.then { |_name, values| Browse.field_query("classification_ssim", values) }
  end

  def response(collections: [], classification: [], places: [], queries: {})
    flat = ->(pairs) { pairs.flatten(1) }
    { "facet_counts" => { "facet_fields" => { "collection_ssim" => flat.(collections), "classification_ssim" => flat.(classification), "production_place_ssim" => flat.(places) },
                          "facet_queries" => queries } }
  end

  test "the curated kinds are in the file, sentence case, and no classification value belongs to two kinds" do
    kinds = ExploreEntryPoints.kinds

    assert_operator kinds.size, :>=, 6
    assert_operator kinds.size, :<=, 10
    kinds.each { |label, values| assert_equal label, label.upcase_first, "#{label} is not sentence case"; assert_not_empty values }
    all_values = kinds.flat_map(&:last)
    assert_equal all_values.uniq, all_values
  end

  test "a kind keeps the values the index has and the real count of records with any of them; missing values are skipped" do
    queries = { kind_query("Prints and drawings") => 7192 }
    counts = ExploreEntryPoints.parse(response(classification: [ [ "prints", 4845 ], [ "paintings", 2555 ] ], queries: queries))

    assert_equal [ [ "Prints and drawings", 7192, [ "prints" ] ] ], counts["kinds"]
    assert_equal({ f: { "classification_ssim" => [ "prints" ] } }, ExploreEntryPoints.overview(counts.merge("collections" => [])).kinds.first.query.slice(:f))
  end

  test "a kind whose values are all missing, or with no records, is left out" do
    queries = { kind_query("Paintings") => 0, kind_query("Photographs") => 12 }
    counts = ExploreEntryPoints.parse(response(classification: [ [ "paintings", 1 ] ], queries: queries))
    assert_equal [ "Photographs" ], counts["kinds"].map(&:first)

    assert_empty ExploreEntryPoints.overview(counts).kinds # Photographs has 12 records but no value in the index: nothing to link to
  end

  test "a kind with several values links to the any-of filter, and one with one value to the plain filter" do
    counts = { "kinds" => [ [ "Prints and drawings", 7192, %w[prints drawings] ], [ "Paintings", 2555, [ "paintings" ] ] ] }
    links = ExploreEntryPoints.overview(counts).kinds

    assert_equal({ "classification_ssim" => %w[prints drawings] }, links.first.query[:f_inclusive])
    assert_equal({ "classification_ssim" => [ "paintings" ] }, links.last.query[:f])
    assert(links.all? { |link| link.query[:any_assets] == "1" })
  end

  test "collections: the hidden value, the very small ones and everything over the limit are left out, most records first" do
    list = [ [ "University Art Collection", 14_537 ], [ "[other]", 5000 ], [ "Medical History Museum", 13_979 ], [ "University of Melbourne", 4 ],
             [ "Grainger Museum Collection", 12_849 ], [ "Henry Forman Atkinson Dental Museum", 5331 ], [ "Indigenous Collections", 1540 ],
             [ "Harry Brookes Allen Museum of Anatomy and Pathology", 1331 ], [ "Another collection", 900 ] ]
    counts = ExploreEntryPoints.parse(response(collections: list))
    names = counts["collections"].map(&:first)

    assert_equal 6, names.size
    assert_not_includes names, "[other]"
    assert_not_includes names, "University of Melbourne"
    assert_not_includes names, "Another collection"
    assert_equal "University Art Collection", names.first
  end

  test "places: the repeated and enclosing values are skipped and five are kept" do
    places = [ [ "Oceania", 8642 ], [ "Australia", 8056 ], [ "Europe", 6842 ], [ "Victoria", 4430 ], [ "Melbourne", 3279 ], [ "United Kingdom", 3083 ],
               [ "Melbourne, Victoria, Australia", 2796 ], [ "England", 2548 ] ]
    kept = ExploreEntryPoints.parse(response(places: places))["places"].map(&:first)

    assert_equal [ "Australia", "Europe", "Victoria", "Melbourne", "United Kingdom" ], kept
  end

  test "periods with no records are left out; the others link to the range filter" do
    counts = { "periods" => { ExploreEntryPoints.period_key(-10_000, 1799) => 0, ExploreEntryPoints.period_key(1800, 1899) => 7, ExploreEntryPoints.period_key(1900, 1999) => 9 } }
    links = ExploreEntryPoints.overview(counts.merge("collections" => [ [ "x", 1 ] ])).periods

    assert_equal [ "1800s", "1900s" ], links.map(&:label)
    assert_equal "1800", links.first.query.dig(:range, "date_start_isi", :begin).to_s
  end

  test "the tints go round in order, and tile counts are exact numbers" do
    pairs = Array.new(7) { |n| [ "Collection #{n}", 1000 + n ] }
    tiles = ExploreEntryPoints.overview({ "collections" => pairs }).collections

    assert_equal [ 1, 2, 3, 4, 5, 6, 1 ], tiles.map(&:tint)
    assert_equal 1003, tiles[3].count
  end

  test "no counts at all (Solr down and nothing kept): an empty overview, so no section" do
    assert_not ExploreEntryPoints.overview({}).any?
  end

  test "Solr down and nothing kept gives no counts" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    assert_equal({}, ExploreEntryPoints.counts(Object.new.tap { |c| c.define_singleton_method(:get) { |*| raise Errno::ECONNREFUSED } }))
  ensure
    Rails.cache = original_cache
  end
end
