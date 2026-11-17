require "application_system_test_case"

# The empty results page, against the Solr core at SOLR_URL: "skull" matches hundreds of records, none with a digital
# asset, so the default filter hides every one of them. (System tests, so CI's "system" job, which has Solr, runs them.)
class ZeroResultsTest < ApplicationSystemTestCase
  setup do
    page.driver.set_cookie("country_acknowledged", "1")
  end

  def link_query(selector)
    Rack::Utils.parse_nested_query(URI(find(selector)[:href]).query)
  end

  def unfiltered_total
    Blacklight::Solr::Repository.new(CatalogController.blacklight_config).search(params: { q: "skull", rows: 0 }).total
  end

  test "zero results with the default filter say how many results the filter hides, and link to them" do
    visit search_catalog_path(q: "skull", search_field: "all_fields", f: { has_digital_asset: [ "with" ] })

    assert_selector ".results-empty__title", text: "No results match your filters."
    assert_no_text(/no suggestions/i)
    total = unfiltered_total
    assert_operator total, :>, 0
    assert_selector "a.results-empty__unfiltered", exact_text: "#{total} results without the ‘With Digital Asset’ filter"

    query = link_query("a.results-empty__unfiltered")
    assert_equal "skull", query["q"]
    assert_equal "1", query["any_assets"]
    assert_nil query["f"]
  end

  test "Clear all filters keeps the search and the search field, and removes only the filters" do
    visit search_catalog_path(q: "skull", search_field: "all_fields",
                              f: { has_digital_asset: [ "with" ], collection_ssim: [ "Grainger Museum" ] })

    assert_equal({ "q" => "skull", "search_field" => "all_fields", "any_assets" => "1" }, link_query("a.results-empty__button"))
    assert_selector "a.results-empty__unfiltered", text: /\A\d+ results without these filters\z/
  end

  test "a search that finds nothing even without its filters keeps the Jira wording and offers a new search instead" do
    visit search_catalog_path(q: "zzzqxqxnomatch", f: { has_digital_asset: [ "with" ] })

    assert_selector ".results-empty__title", exact_text: I18n.t("blacklight.search.zero_results.title")
    assert_no_selector "a.results-empty__unfiltered"
    assert_no_link "Clear all filters"
    assert_selector "a.results-empty__new-search[href='/']"
  end
end
