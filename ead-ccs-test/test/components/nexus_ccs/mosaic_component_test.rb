require "test_helper"

class MosaicComponentTest < ViewComponent::TestCase
  def tile(title, lead: false) = HomeSections::Tile.new(title: title, text: "A line", path: "/x/#{title.parameterize}", image: "/a.jpg", lead: lead, cta: (lead ? "Go" : nil), external: false)

  test "a list of tiles, each the site's card in its tile variant: the name an h3 link, the picture's link hidden, the lead marked" do
    render_inline NexusCcs::MosaicComponent.new(tiles: [ tile("One"), tile("Two", lead: true) ], pattern: :five, label: "Museums")

    assert_selector "ul.mosaic.mosaic--five[aria-label=Museums] > li", count: 2
    assert_selector "li.mosaic__item--lead article.result-card.explore-card.explore-card--tile.explore-card--lead h3 a[href='/x/two']", text: "Two"
    assert_selector "a.result-card__media[tabindex='-1'][aria-hidden=true] img[alt='']", count: 2
    assert_selector "li.mosaic__item--lead .explore-card__cta[aria-hidden=true]", text: "Go"
    assert_selector "h3 a", count: 2
  end

  test "an unknown pattern is refused" do
    assert_raises(ArgumentError) { NexusCcs::MosaicComponent.new(tiles: [], pattern: :zigzag, label: "x") }
  end
end
