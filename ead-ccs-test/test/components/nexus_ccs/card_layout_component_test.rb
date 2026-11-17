# frozen_string_literal: true

require "test_helper"

class NexusCcs::CardLayoutComponentTest < ViewComponent::TestCase
  Card = Data.define(:label, :query, :image, :intro)

  def cards(count = 8) = (1..count).map { |number| Card.new("Card #{number}", { any_assets: "1", f: { "classification_ssim" => [ "Card #{number}" ] } }, nil, "About card #{number}.") }

  def render_layout(layout, count: 8, **options)
    render_inline NexusCcs::CardLayoutComponent.new(cards: cards(count), layout: layout, label: "Object types", **options)
  end

  test "every layout is a list of cards with the layout's class and the number of cards" do
    NexusCcs::CardLayoutComponent::LAYOUTS.each do |layout|
      render_layout(layout)

      assert_selector ".card-layout.card-layout--#{layout}[data-count='8'] ul.card-layout__list > li.card-layout__item", count: 8
      assert_selector "article.explore-card h3 a[href*='classification_ssim']", count: 8
      assert_selector ".explore-card__intro", text: "About card 1."
    end
  end

  test "an unknown layout is an error" do
    assert_raises(ArgumentError) { render_layout(:carousel) }
  end

  test "the rail's row can be reached by keyboard and has buttons that are hidden until the script shows them" do
    render_layout(:rail)

    assert_selector "ul.card-layout__list[tabindex='0'][aria-label='Object types']"
    assert_selector "button.card-rail__button--previous[hidden][aria-label='Previous Object types']", visible: :all
    assert_selector "button.card-rail__button--next[hidden][aria-label='Next Object types']", visible: :all
  end

  test "the other layouts have no buttons" do
    render_layout(:bento)

    assert_no_selector "button", visible: :all
  end

  test "the wall has its panel after the first card, so the reading order follows the picture" do
    render_layout(:wall, panel: { title: "All subjects, A to Z", text: "What the objects are about.", link: "See all subjects", path: "/browse/subjects" })

    items = page.all("li.card-layout__item")
    assert_equal 9, items.size
    assert items[1][:class].include?("card-layout__item--panel")
    assert_selector ".card-layout__panel h3", text: "All subjects, A to Z"
    assert_selector ".card-layout__panel a[href='/browse/subjects']", text: "See all subjects"
  end

  test "a wall without a panel is just the cards" do
    render_layout(:wall)

    assert_selector "li.card-layout__item", count: 8
    assert_no_selector ".card-layout__panel"
  end
end
