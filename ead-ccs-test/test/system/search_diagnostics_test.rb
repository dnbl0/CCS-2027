require "application_system_test_case"

# CCS-43 in a browser: the panel opens from the keyboard, keeps focus on its button, and has no axe violations.
class SearchDiagnosticsSystemTest < ApplicationSystemTestCase
  setup { page.driver.set_cookie("country_acknowledged", "1") }

  test "the panel opens with Enter, focus stays on its button, and the page has no axe violations" do
    visit search_catalog_path(q: "skull", search_field: "all_fields", f: { has_digital_asset: [ "with" ] })
    assert_selector "details.why-results:not([open])"
    page.execute_script("document.querySelector('.why-results__summary').focus()")
    page.driver.browser.keyboard.type(:Enter)

    assert_selector "details.why-results[open]"
    assert page.evaluate_script("document.activeElement.matches('.why-results__summary')")
    assert_selector ".why-results a", text: /Take off “With a digital asset”/
    assert_accessible
  end
end
