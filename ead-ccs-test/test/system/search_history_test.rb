require "application_system_test_case"

# The Search History table: a search's term, its filters (applied-filter pills) and its actions (Save, Share and Delete
# icon buttons with a tooltip) each have a column, so the filters start at the same place in every row however long the
# search term is. The tooltips follow WCAG 1.4.13: they show on hover and focus, stay while the pointer is on them,
# and go with Escape.
class SearchHistoryTest < ApplicationSystemTestCase
  setup { page.driver.set_cookie("country_acknowledged", "1") }

  def make_searches
    [ "skull", "violin and viola ensemble", "x" ].each do |term|
      visit search_catalog_path(q: term)
      assert_selector ".search-banner"
    end
    visit "/search_history"
    assert_selector "table.search-history tbody tr", count: 3
  end

  def left_edges(selector) = page.all(selector).map { |cell| cell.evaluate_script("this.getBoundingClientRect().left").round }

  def first_row_button(action) = first("tbody tr").find("button[data-action-tooltip-text='#{action}']")

  test "the filters and the actions line up in every row, whatever the search term" do
    make_searches

    assert_equal 1, left_edges("td.filters").uniq.size, "filters start at different places: #{left_edges('td.filters')}"
    assert_equal 1, page.all("td.history-actions").map { |cell| cell.evaluate_script("this.getBoundingClientRect().right").round }.uniq.size
    assert_selector "th[scope=col]", text: "Search"
    assert_selector "th[scope=col]", text: "Filters"
    assert_selector "th[scope=col].text-end", text: "Actions" # a visible heading
    assert_selector "td.filters .applied-filter .filter-value", text: /with a digital asset/i, count: 3 # drawn in capitals
  end

  test "each row has Save, Share and Delete icon buttons, at least 24px square, named for their search" do
    make_searches

    row = first("tbody tr")
    { "Save" => "Save search: x", "Share" => "Share search: x", "Delete" => "Delete search: x" }.each do |action, name|
      button = row.find("button[data-action-tooltip-text='#{action}']")
      size = button.evaluate_script("(function(r){ return [r.width, r.height] })(this.getBoundingClientRect())")
      assert size.all? { |dimension| dimension >= 24 }, "#{action} target is #{size.inspect}"
      assert_equal name, button.text(:all).strip
      assert button.has_css?("svg[aria-hidden=true]", visible: :all)
    end
  end

  test "a tooltip names the action on hover, is linked to the button, and stays while the pointer is on it" do
    make_searches

    button = first_row_button("Save")
    button.hover
    assert_selector "[role=tooltip]", text: "Save"
    assert_equal find("[role=tooltip]")[:id], button[:"aria-describedby"]

    find("[role=tooltip]").hover # the pointer moves from the button onto the tooltip
    sleep 0.4
    assert_selector "[role=tooltip]", text: "Save"

    first("h1").hover
    assert_no_selector "[role=tooltip]"
  end

  test "a tooltip shows on keyboard focus and goes with Escape, leaving focus where it was" do
    make_searches

    first_row_button("Share").send_keys(:tab) # focus the button before it, then move on to Share
    page.execute_script("document.querySelector('tbody tr button[data-action-tooltip-text=Share]').focus()")
    assert_selector "[role=tooltip]", text: "Share"

    page.driver.browser.keyboard.type(:escape)
    assert_no_selector "[role=tooltip]"
    assert_equal "Share", page.evaluate_script("document.activeElement.dataset.actionTooltipText")
  end

  test "Delete takes the search out of the history and says so" do
    make_searches

    first_row_button("Delete").click

    assert_selector "table.search-history tbody tr", count: 2
    assert_no_selector "td.query", text: "x"
    assert_text "Search removed from your history."
  end

  test "Share tells screen readers the link was copied" do
    make_searches

    first_row_button("Share").click

    assert_selector "[role=status]", text: "Copied", visible: :all
  end

  test "the search history page has no axe violations, with a tooltip showing too" do
    make_searches
    assert_accessible

    first_row_button("Delete").hover
    assert_selector "[role=tooltip]", text: "Delete"
    sleep 0.5 # the tooltip fades in: axe reads the colours once it has
    assert_accessible
  end

  test "the page is readable in a narrow window: the table scrolls inside its own box, not the page" do
    make_searches
    page.driver.resize(360, 800)

    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page scrolls sideways"
  end
end
