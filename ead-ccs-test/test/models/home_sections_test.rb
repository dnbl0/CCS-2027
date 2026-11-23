require "test_helper"

# The tiles of the home page's mosaics (the homepage redesign, 2026-11), from config/pages.yml and the index
class HomeSectionsTest < ActiveSupport::TestCase
  def helpers = ApplicationController.new.tap { |c| c.request = ActionDispatch::TestRequest.create }.view_context

  def named_value(name, count, image: true) = { "value" => name, "count" => count, "image" => (image ? { "path" => "https://example.test/#{count}.jpg" } : nil) }

  def tile(label, image: nil) = ExploreEntryPoints::Tile.new(label: label, count: 1, query: BrowseHubs.query("collection_ssim", label), image: image, tint: 1, intro: nil)

  test "the collections: every one, the University Art Collection first as the lead with its blurb, each picture with its size" do
    image = ExploreEntryPoints::Image.new(id: "x", title: "x", path: "/film-thumbs/a.jpg", width: 1200, height: 800)
    tiles = HomeSections.collections([ tile("Medical History Museum", image: image), tile("University Art Collection", image: image), tile("Indigenous Collections", image: image) ], helpers)

    assert_equal [ "University Art Collection", "Medical History Museum", "Indigenous Collections" ], tiles.map(&:title)
    assert_equal [ true, false, false ], tiles.map(&:lead)
    assert_equal SitePages.collection("university-art-collection")["blurb"], tiles.first.text
    assert_equal [ 1200, 800 ], [ tiles.first.width, tiles.first.height ]
    assert_nil tiles.last.image # Indigenous Collections is kept text only
    assert tiles.drop(1).all? { |tile| tile.text.nil? } # no record counts
  end

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

  test "the named collections: only those with a picture, eight or none, the largest leading first" do
    values = (1..9).map { |n| named_value("Bequest #{n}", 1000 - n) } + [ named_value("No picture", 5000, image: false) ]
    tiles = HomeSections.named(values, helpers)

    assert_equal 8, tiles.size
    assert_equal "Bequest 1", tiles.first.title
    assert tiles.first.lead
    assert_nil tiles.first.cta # the lead has no call to action: the whole card is the link
    assert_not tiles.map(&:title).include?("No picture")
    assert tiles.all? { |tile| tile.text.nil? } # no record counts
    assert_equal [], HomeSections.named(values.first(7), helpers) # too few for the mosaic: the section is left out
  end
end
