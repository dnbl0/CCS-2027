require "application_system_test_case"

# The browse index pages and an entity page in a real browser: axe at desktop and phone width, the filter without a mouse, and a
# keyboard-only path from the hub to an entity page. Needs the shared Solr core.
class BrowseSystemTest < ApplicationSystemTestCase
  setup do
    page.driver.set_cookie("country_acknowledged", "1")
    needs_solr
  end

  # The result card's title is an h5 on every page that draws it (NexusCcs::ResultCardComponent::TITLE_TAG); a best-practice
  # rule, tracked with the card, not with these pages
  HEADING_ORDER = %w[heading-order].freeze

  WIDTHS = { "desktop" => [ 1440, 900 ], "320px" => [ 320, 700 ] }.freeze

  WIDTHS.each do |name, size|
    test "the overview, a hub and an entity page have no axe violations at #{name}" do
      page.driver.resize(*size)
      [ "/browse", "/browse/makers?letter=G", "/browse/periods", "/browse/periods/1900-1999" ].each do |path|
        visit path
        assert_selector "h1"
        assert_accessible(tags: AXE_TAGS + WCAG22_TAGS, except: HEADING_ORDER)
      end
      visit "/browse/makers?filter=bunny"
      first(".browse__link").click
      assert_selector ".result-card"
      assert_accessible(tags: AXE_TAGS + WCAG22_TAGS, except: HEADING_ORDER)
      assert_no_horizontal_scroll if name == "320px"
    end
  end

  test "the filter box is filled in and submitted with the keyboard, and the result opens with Enter" do
    visit "/browse/subjects"
    find("#filter").send_keys("portr", :enter)
    assert_current_path(/filter=portr/)
    assert_selector ".browse__link"
    find(".browse__link", match: :first).send_keys(:enter) # a result opens with the keyboard
    assert_selector "h1"
    assert_selector ".browse-facts"
  end

  def assert_no_horizontal_scroll
    assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"), "the page scrolls sideways at 320px"
  end
end
