# frozen_string_literal: true

require "test_helper"

class StackComponentTest < ViewComponent::TestCase
  def tiles(count) = Array.new(count) { |index| HomeSections::Tile.new(title: "Card #{index}", text: "Line #{index}", path: "/card/#{index}", image: "/card-#{index}.jpg", lead: false, cta: nil, external: false, width: nil, height: nil) }

  test "with captions: each card's picture, its title as the link and its line, the middle card at the centre" do
    render_inline NexusCcs::StackComponent.new(tiles: tiles(5), label: "Cards")

    assert_selector "ul.stack:not(.stack--bare)[aria-label='Cards'] > li.stack__item", count: 5
    assert_selector "li.stack__item.is-centre[data-away='0'][data-side='0']", text: "Card 2"
    assert_selector "li.stack__item[data-away='2'][data-side='-1']", text: "Card 0"
    assert_selector ".stack__text", text: "Line 4"
  end

  test "picture-only (Google's \"What do you want explore?\"): no line under the picture, the name still the card's link; four cards centre on the third" do
    render_inline NexusCcs::StackComponent.new(tiles: tiles(4), label: "Ways", captions: false)

    assert_selector "ul.stack.stack--bare > li.stack__item", count: 4
    assert_selector "li.stack__item.is-centre", text: "Card 2"
    assert_selector "a.stack__link[href='/card/3']", text: "Card 3"
    assert_no_selector ".stack__text"
  end
end
