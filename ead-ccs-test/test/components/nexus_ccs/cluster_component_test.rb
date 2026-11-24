require "test_helper"

# Google Arts & Culture's cluster (NexusCcs::ClusterComponent): three or four pictured cards in one block, each card's title its link
class ClusterComponentTest < ViewComponent::TestCase
  def tile(title, image: "https://example.org/#{title}.jpg") = HomeSections::Tile.new(title: title, text: "A line", path: "/catalog/#{title}", image: image,
                                                                                        lead: false, cta: nil, external: false, width: nil, height: nil)

  test "four cards with pictures: one block of four, each card's title its link and its line on the picture" do
    render_inline NexusCcs::ClusterComponent.new(tiles: %w[a b c d e].map { |title| tile(title) }, label: "On this day")
    assert_selector "ul.cluster[data-count='4'][aria-label='On this day'] li.cluster__item", count: 4
    assert_selector ".cluster__card img.cluster__image[alt='']", count: 4
    assert_selector ".cluster__card h3 a.cluster__link[href='/catalog/a']", text: "a"
    assert_selector ".cluster__text", text: "A line", count: 4
  end

  test "only cards with a picture count: three make the three-card block, fewer show nothing" do
    render_inline NexusCcs::ClusterComponent.new(tiles: [ tile("a"), tile("b", image: nil), tile("c"), tile("d") ], label: "On this day")
    assert_selector "ul.cluster[data-count='3'] li", count: 3

    assert_not NexusCcs::ClusterComponent.new(tiles: [ tile("a"), tile("b") ], label: "On this day").render?
  end
end
