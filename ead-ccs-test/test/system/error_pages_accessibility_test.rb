require "application_system_test_case"
require_relative "../support/outages"

# axe-core over each error page, as a browser gets it: the failed request is answered by the site's own page (ErrorsController)
class ErrorPagesAccessibilityTest < ApplicationSystemTestCase
  include Outages

  setup { page.driver.set_cookie("country_acknowledged", "1") }

  Outages::ERRORS.each_key do |code|
    test "the #{code} page has no axe violations and a main landmark, one h1 and a way on" do
      with_error_page(code) do
        visit "/help"
        assert_selector "main#main-content"
        assert_selector "h1", count: 1
        assert_selector ".error-page__links a", minimum: 1
        assert_accessible
      end
    end
  end

  test "the Search is unavailable page has no axe violations" do
    with_solr_down do
      visit search_catalog_path(any_assets: "1", q: "skull")
      assert_selector "h1", text: "Search is unavailable"
      assert_accessible
    end
  end
end
