require "test_helper"

class MosaicComponentTest < ViewComponent::TestCase
  def tile(title, lead: false, width: nil, height: nil)
    HomeSections::Tile.new(title: title, text: "A line", path: "/x/#{title.parameterize}", image: "/a.jpg", lead: lead, cta: (lead ? "Go" : nil), external: false,
                           width: width, height: height)
  end

  test "a list of tiles, each the site's card in its tile variant: the name an h3 link, the picture's link hidden, the lead marked" do
    render_inline NexusCcs::MosaicComponent.new(tiles: [ tile("Two", lead: true, width: 1100, height: 550), tile("One") ], label: "Museums")

    assert_selector "ul.mosaic-flow[data-controller=mosaic][data-mosaic-base-value='4'][aria-label=Museums] > li.mosaic-flow__item", count: 2
    assert_selector "li.mosaic-flow__item--lead[style='--a: 2.0'] article.result-card.explore-card.explore-card--tile.explore-card--lead h3 a[href='/x/two']", text: "Two"
    assert_selector "a.result-card__media[tabindex='-1'][aria-hidden=true] img[alt='']", count: 2
    assert_selector "li.mosaic-flow__item--lead .explore-card__cta[aria-hidden=true]", text: "Go"
    assert_selector "li.mosaic-flow__item:not([style])", count: 1 # a picture of unknown size is measured in the browser
    assert_selector "h3 a", count: 2
  end

  test "a very wide or very tall picture is held to a sensible shape" do
    render_inline NexusCcs::MosaicComponent.new(tiles: [ tile("Wide", width: 5000, height: 500), tile("Tall", width: 100, height: 1000) ], label: "x")

    assert_selector "li[style='--a: 2.6']"
    assert_selector "li[style='--a: 0.5']"
  end
end
