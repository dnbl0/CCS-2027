require "application_system_test_case"

# axe-core (WCAG 2.1 A and AA) over the pages and the states people reach by clicking
class AccessibilityTest < ApplicationSystemTestCase
  setup { page.driver.set_cookie("country_acknowledged", "1") }

  PAGES = {
    "home" => "/",
    "help" => "/help",
    "indigenous cultural data" => "/help/indigenous-data",
    "contact" => "/contact",
    "advanced search" => "/catalog/advanced"
  }.freeze

  PAGES.each do |name, path|
    test "#{name} has no axe violations" do
      visit path
      assert_accessible
    end
  end

  test "the check fails on a page with a violation, so a pass means something" do
    visit "/contact"
    page.execute_script("document.body.insertAdjacentHTML('beforeend', '<img src=\"/icon.png\"><button></button>')")

    error = assert_raises(Minitest::Assertion) { assert_accessible }
    assert_match(/image-alt/, error.message)
    assert_match(/button-name/, error.message)
  end

  test "search results have no axe violations" do
    visit search_catalog_path(any_assets: "1", q: "skull")
    assert_selector ".result-card"
    assert_accessible
  end

  test "a record page has no axe violations" do
    visit search_catalog_path(any_assets: "1", q: "skull")
    first(".result-card .document-title-heading a").click
    assert_no_selector ".result-card" # the results page has an h1 too: wait until the record page has replaced it
    assert_selector "h1"
    assert_no_selector "html[aria-busy]" # Turbo marks the page busy while it navigates; axe flags that on the html element
    assert_accessible
  end

  test "the home page with the Acknowledgement of Country open has no axe violations" do
    page.driver.clear_cookies
    visit root_path
    assert_selector "#country-acknowledgement[open]"
    assert_accessible
  end
end
