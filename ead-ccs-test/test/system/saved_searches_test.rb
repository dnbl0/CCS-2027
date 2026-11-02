require "application_system_test_case"

# The Saved searches page: the same table and icon actions as the Search history page, without Save.
class SavedSearchesSystemTest < ApplicationSystemTestCase
  setup { page.driver.set_cookie("country_acknowledged", "1") }

  def save_a_search(term)
    visit search_catalog_path(q: term)
    assert_selector ".search-banner"
    visit "/search_history"
    first("tbody tr").find("button[data-action-tooltip-text='Save']").click
    assert_selector "table.saved-searches"
  end

  test "Delete removes a saved search; Share says the link was copied; the actions line up under their heading" do
    save_a_search("skull")
    save_a_search("violin")
    assert_selector "table.saved-searches tbody tr", count: 2

    heading = find("th.history-actions-heading").evaluate_script("this.getBoundingClientRect().left + parseFloat(getComputedStyle(this).paddingLeft)").round
    assert_in_delta heading, first(".history-actions__group").evaluate_script("this.getBoundingClientRect().left").round, 1

    first("button[data-action-tooltip-text='Share']").click
    assert_selector "[role=status]", text: "Copied", visible: :all

    first("button[data-action-tooltip-text='Delete']").click
    assert_selector "table.saved-searches tbody tr", count: 1
  end

  test "the saved searches page has no axe violations, with a tooltip showing too" do
    save_a_search("skull")
    assert_accessible

    first("button[data-action-tooltip-text='Delete']").hover
    assert_selector "[role=tooltip]", text: "Delete"
    sleep 0.5 # the tooltip fades in: axe reads the colours once it has
    assert_accessible
  end

  test "the page does not scroll sideways in a narrow window" do
    save_a_search("skull")
    page.driver.resize(360, 800)

    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
  end
end
