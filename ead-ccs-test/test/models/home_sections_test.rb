require "test_helper"

# The tiles of the home page's mosaics (the homepage redesign, 2026-11), from config/pages.yml and the index
class HomeSectionsTest < ActiveSupport::TestCase
  def helpers = ApplicationController.new.tap { |c| c.request = ActionDispatch::TestRequest.create }.view_context

  def named_value(name, count, image: true) = { "value" => name, "count" => count, "image" => (image ? { "path" => "https://example.test/#{count}.jpg" } : nil) }

  def tile(label, image: nil) = ExploreEntryPoints::Tile.new(label: label, count: 1, query: BrowseHubs.query("collection_ssim", label), image: image, tint: 1, intro: nil)

  test "a collage takes the records a place may show, preferring ones the places before it have not used" do
    docs = ->(ids) { Showcase::Result.new(total: 9, documents: ids.map { |id| SolrDocument.new("id" => id, "thumbnail_path_ssi" => "/t/#{id}.jpg", "title_tsim" => [ id ]) }, facets: {}) }
    places = [ tile("Australia"), tile("Victoria") ]
    results = { "Australia" => docs.call(%w[a b c d]), "Victoria" => docs.call(%w[a b e f]) }
    original = Showcase.method(:call)
    Showcase.define_singleton_method(:call) { |fq:, **| results.fetch(fq.first[/"([^"]+)"/, 1]) }
    collages = HomeSections.place_collages(places, helpers)
    assert_equal %w[a b c d], collages.first.pictures.map { |picture| picture[:title] }
    assert_equal %w[e f a b], collages.last.pictures.map { |picture| picture[:title] }
  ensure
    Showcase.define_singleton_method(:call, original) if original
  end
end
