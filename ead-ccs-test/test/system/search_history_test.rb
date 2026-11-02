require "application_system_test_case"

# The Search History table: a search's term, its filters and its Save button each have a column, so the filters start
# at the same place in every row however long the search term is.
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

  test "the filters and the Save buttons line up in every row, whatever the search term" do
    make_searches

    assert_equal 1, left_edges("td.filters").uniq.size, "filters start at different places: #{left_edges('td.filters')}"
    assert_equal 1, page.all("td.save-search").map { |cell| cell.evaluate_script("this.getBoundingClientRect().right").round }.uniq.size
    assert_selector "th[scope=col]", text: "Search"
    assert_selector "th[scope=col]", text: "Filters"
    assert_selector "th[scope=col] .visually-hidden", text: "Actions", visible: :all
  end

  test "the Save this search buttons are at least 24px square and name their search" do
    make_searches

    page.all("td.save-search button").each do |button|
      size = button.evaluate_script("(function(r){ return [r.width, r.height] })(this.getBoundingClientRect())")
      assert size.all? { |dimension| dimension >= 24 }, "target is #{size.inspect}"
      assert_match(/\ASave this search: /, button[:"aria-label"]) # starts with the visible text (label in name)
    end
  end

  test "the search history page has no axe violations" do
    make_searches

    assert_accessible
  end

  test "the page is readable in a narrow window: the table scrolls inside its own box, not the page" do
    make_searches
    page.driver.resize(360, 800)

    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page scrolls sideways"
  end
end
