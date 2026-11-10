require "application_system_test_case"

# The advanced search page (the CCS design, Figma "Advanced search"): Blacklight's own form under a page banner, beside the search tips.
class AdvancedSearchTest < ApplicationSystemTestCase
  setup { page.driver.set_cookie("country_acknowledged", "1") }

  test "the page banner is the one h1, with the form and the search tips beside each other" do
    visit "/catalog/advanced"

    assert_selector "h1", count: 1
    assert_selector ".page-banner h1", text: "Advanced search"
    assert_no_selector ".page-banner .page-banner__desc"
    assert_selector ".advanced-search__form form.advanced"
    assert_selector ".advanced-search__tips section.advanced-search-tips h2", text: "Search tips"
    assert_selector "ul.advanced-help > li", count: 8
  end

  test "the match heading reads 'Find items that match all of the fields below'" do
    visit "/catalog/advanced"

    assert_selector "h2.query-criteria-heading", text: /Find items that match .* of the fields below/m
    assert_selector "h2.query-criteria-heading select#op option", count: 2, visible: :all
    assert_selector "h2.limit-criteria-heading", text: /have these attributes/
  end

  test "the form and the tips sit side by side on desktop and stack on a tablet" do
    visit "/catalog/advanced"
    form, tips = %w[.advanced-search__form .advanced-search__tips].map { |s| find(s).evaluate_script("this.getBoundingClientRect().toJSON()") }
    assert_operator tips["left"], :>=, form["right"]
    assert_in_delta 376, tips["width"], 1

    page.driver.resize(820, 1000)
    visit "/catalog/advanced"
    form, tips = %w[.advanced-search__form .advanced-search__tips].map { |s| find(s).evaluate_script("this.getBoundingClientRect().toJSON()") }
    assert_operator tips["top"], :>=, form["bottom"]
  ensure
    page.driver.resize(1440, 900)
  end

  test "a form sent with nothing in it shows the notification once, and a search with a term does not" do
    visit "/catalog/advanced"
    assert_no_selector ".advanced-search__notice"

    click_button "advanced-search-submit"
    assert_current_path "/catalog/advanced?op=must"
    assert_selector ".advanced-search__notice[role=alert]", text: "There is a problem with your search"
    assert_text "Enter at least one search term, or choose an attribute to search by."

    visit "/catalog/advanced"
    assert_no_selector ".advanced-search__notice"

    fill_in "All Fields", with: "skull"
    click_button "advanced-search-submit"
    assert_selector ".constraints-label"
    assert_no_selector ".advanced-search__notice"
  end

  test "every workbook filter is an attribute, in the sheet's order; one with no data yet shows the note and no checkboxes" do
    visit "/catalog/advanced"

    labels = all("#advanced_search_facets .facet-field-heading button", visible: :all).map { |b| b.text(:all).strip }
    assert_equal DataModel.filters.map(&:name), labels - [ "Digital asset" ]

    find("#facet-pending_film_gaming_classification-header button").click
    within("#facet-pending_film_gaming_classification") do
      assert_text "No records have this information yet."
      assert_no_selector "input[type=checkbox]"
    end
    assert_accessible
  end

  test "a year filter takes a From and a To year, and searches that range" do
    visit "/catalog/advanced"
    find("#facet-date_start_isi-header button").click
    within("#facet-date_start_isi") do
      fill_in "From", with: "1900"
      fill_in "To", with: "1910"
    end
    assert_accessible
    click_button "advanced-search-submit"

    assert_current_path(/range%5Bdate_start_isi%5D%5Bbegin%5D=1900/)
    assert_selector ".constraint-value", text: /1900.*1910/
  end

  test "no attribute lists more than 100 values, so the page stays a usable size" do
    visit "/catalog/advanced"

    counts = all(".advanced-facet-limits .facet-values", visible: :all).map { |list| list.all("li", visible: :all).size }
    assert_not_empty counts
    assert_operator counts.max, :<=, 100
  end
end
