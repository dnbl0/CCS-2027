require "application_system_test_case"

# CCS-212: choosing a filter keeps the open filters open, keeps keyboard focus on the filter that was used, and says
# (politely) how many results and filters now apply. The values narrowing is in test/integration/dynamic_filters_test.rb.
class DynamicFiltersSystemTest < ApplicationSystemTestCase
  setup { page.driver.set_cookie("country_acknowledged", "1") }

  def press(key) = page.driver.browser.keyboard.type(key)

  def active_id = page.evaluate_script("document.activeElement.getAttribute('aria-controls') || document.activeElement.id")

  test "choosing a filter with the keyboard keeps the filter open, keeps focus on it, and announces the new results" do
    visit search_catalog_path(q: "", any_assets: "1")
    toggle = find("#sidebar .accordion-button", text: "Object Type")
    toggle.click
    assert_selector "#facet-object_type_ssim.show"
    assert_accessible

    find("#facet-object_type_ssim .facet-select", match: :first).send_keys(:enter)

    assert_selector "#facet-object_type_ssim.show", wait: 6
    assert_equal "true", find("#sidebar .accordion-button", text: "Object Type")["aria-expanded"]
    assert_equal "facet-object_type_ssim", active_id, "focus was lost when the results changed"
    assert_selector "#sidebar [role=status]", text: /results, 1 filter applied/, visible: :all
    assert_equal "polite", find("#sidebar [role=status]", visible: :all)["aria-live"]
    assert_accessible
  end

  test "a page reached any other way says nothing, and opens only the filter that has a value chosen" do
    visit search_catalog_path(q: "", any_assets: "1", f: { collection_ssim: [ "Medical History Museum" ] })
    assert_selector "#sidebar .accordion-button[aria-expanded=true]", count: 1
    sleep 0.4
    assert_empty find("#sidebar [role=status]", visible: :all).text(:all).strip
  end

  test "removing the filter again keeps focus in the sidebar" do
    visit search_catalog_path(q: "", any_assets: "1", f: { collection_ssim: [ "Medical History Museum" ] })
    find("#facet-collection_ssim .remove").send_keys(:enter)
    assert_selector "#sidebar [role=status]", text: /results, no filters applied/, visible: :all
    assert_equal "facet-collection_ssim", active_id
  end

  test "in the phone drawer, which closes with the page change, focus goes to the Filters button" do
    visit search_catalog_path(q: "skull", any_assets: "1")
    page.driver.resize(390, 800)
    find(".filters-toggle").click
    find("#sidebar .accordion-button", text: "Collection Title").click
    find("#facet-collection_ssim .facet-select", match: :first).click

    assert_selector "#sidebar [role=status]", text: /results, 1 filter applied/, visible: :all
    assert_equal "filters-toggle", page.evaluate_script("document.activeElement.className.split(' ')[0]")
  ensure
    page.driver.resize(1440, 900)
  end
end
