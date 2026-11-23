require "test_helper"

# The tiles of the home page's mosaics (the homepage redesign, 2026-11), from config/pages.yml and the index
class HomeSectionsTest < ActiveSupport::TestCase
  def helpers = ApplicationController.new.tap { |c| c.request = ActionDispatch::TestRequest.create }.view_context

  def named_value(name, count, image: true) = { "value" => name, "count" => count, "image" => (image ? { "path" => "https://example.test/#{count}.jpg" } : nil) }

  test "the museums: the lead first with its blurb, then four with no record count, each with its banner's size" do
    tiles = HomeSections.collections(helpers)

    assert_equal 5, tiles.size
    assert_equal [ true ] + [ false ] * 4, tiles.map(&:lead)
    assert_equal "University Art Collection", tiles.first.title
    assert_equal SitePages.collection("university-art-collection")["blurb"], tiles.first.text
    assert tiles.drop(1).all? { |tile| tile.text.nil? } # no record counts (Dean, 2026-11-23)
    assert_equal [ 1100, 550 ], [ tiles.first.width, tiles.first.height ] # so the row can give it its shape
    assert tiles.all? { |tile| tile.image.to_s.include?("banners/") }
  end

  test "the named collections: only those with a picture, eight or none, the largest leading first" do
    values = (1..9).map { |n| named_value("Bequest #{n}", 1000 - n) } + [ named_value("No picture", 5000, image: false) ]
    tiles = HomeSections.named(values, helpers)

    assert_equal 8, tiles.size
    assert_equal "Bequest 1", tiles.first.title
    assert tiles.first.lead
    assert_equal "Explore the collection", tiles.first.cta
    assert_not tiles.map(&:title).include?("No picture")
    assert tiles.all? { |tile| tile.text.nil? } # no record counts
    assert_equal [], HomeSections.named(values.first(7), helpers) # too few for the mosaic: the section is left out
  end
end
