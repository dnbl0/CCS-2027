require "application_system_test_case"

# The Places page in a browser: axe, no sideways scroll, and the search updating the list as it is typed, the box keeping its focus
class PlacesPageSystemTest < ApplicationSystemTestCase
  setup do
    page.driver.set_cookie("country_acknowledged", "1")
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.write("browse_hubs/v1/places", [ [ "Carlton", 13 ], [ "Paris", 321 ], [ "Kyoto", 9 ] ], expires_in: 1.day)
  end

  teardown do
    Rails.cache = @cache
    page.current_window.resize_to(1400, 900)
  end

  test "the A–Z view has no axe violations at desktop and phone width, and the search narrows the list as it is typed" do
    [ [ 1440, 900 ], [ 390, 844 ] ].each do |size|
      page.current_window.resize_to(*size)
      visit "/browse/places?view=az"
      assert_selector "a.places-list__link", count: 3
      assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)
      assert_not page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth"), "no sideways scroll at #{size.first}px"
    end

    page.current_window.resize_to(1440, 900)
    find("#filter").send_keys("car")
    assert_selector "a.places-list__link", count: 1, text: "Carlton"
    assert_current_path(/filter=car/)
    assert_equal "filter", page.evaluate_script("document.activeElement.id"), "the search keeps its focus"
    assert_selector "[role=status]", text: "1 place", visible: :all
  end
end
