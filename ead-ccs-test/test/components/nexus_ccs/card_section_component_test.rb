# frozen_string_literal: true

require "test_helper"

class NexusCcs::CardSectionComponentTest < ViewComponent::TestCase
  test "a section has its heading, the link to the full list, an introduction and its content" do
    render_inline(NexusCcs::CardSectionComponent.new(slug: "places", prefix: "browse", heading: "Places", intro: "Where the objects were made.", see_all: "See all places", see_all_path: "/browse/places")) { "<p id='inside'>cards</p>".html_safe }

    assert_selector "section.ccs-section.browse-places[aria-labelledby='browse-places'] header.explore__row-head h2#browse-places", text: "Places"
    assert_selector "a.explore__all[href='/browse/places']", text: "See all places"
    assert_selector "p.explore__intro", text: "Where the objects were made."
    assert_selector "section #inside"
  end

  test "the introduction is optional" do
    render_inline(NexusCcs::CardSectionComponent.new(slug: "kinds", prefix: "explore", heading: "Record types", see_all: "See all", see_all_path: "/browse/object-types")) { "x" }

    assert_selector "section.explore-kinds"
    assert_no_selector "p.explore__intro"
  end
end
