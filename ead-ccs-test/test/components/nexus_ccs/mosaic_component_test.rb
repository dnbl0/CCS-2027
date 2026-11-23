require "test_helper"

class MosaicComponentTest < ViewComponent::TestCase
  def tile(title, lead: false) = HomeSections::Tile.new(title: title, text: "A line", path: "/x/#{title.parameterize}", image: "/a.jpg", lead: lead, cta: (lead ? "Go" : nil), external: false)

  test "a list of tiles, each one link with its name as an h3 over a decorative picture, the lead marked" do
    render_inline NexusCcs::MosaicComponent.new(tiles: [ tile("One"), tile("Two", lead: true) ], pattern: :five, label: "Museums")

    assert_selector "ul.mosaic.mosaic--five[aria-label=Museums] > li", count: 2
    assert_selector "li.mosaic__item--lead a.cover-card.cover-card--lead[href='/x/two'] h3", text: "Two"
    assert_selector "a.cover-card img.cover-card__image[alt='']", count: 2
    assert_selector "li.mosaic__item--lead .cover-card__cta", text: "Go"
    assert_selector "a", count: 2
  end

  test "an unknown pattern is refused" do
    assert_raises(ArgumentError) { NexusCcs::MosaicComponent.new(tiles: [], pattern: :zigzag, label: "x") }
  end
end
