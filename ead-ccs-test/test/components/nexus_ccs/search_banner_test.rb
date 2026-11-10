require "test_helper"

class SearchBannerTest < ViewComponent::TestCase
  def render_banner(url)
    with_controller_class(CatalogController) do
      with_request_url(url) { render_inline(NexusCcs::SearchBannerComponent.new(blacklight_config: CatalogController.blacklight_config)) }
    end
  end

  test "the banner attaches the select dropdown controller (the Advanced search link is a plain navigation, no modal)" do
    render_banner("/catalog?q=art")

    wrapper = page.find(".search-banner__search")
    assert_equal "select-dropdown", wrapper["data-controller"]
    assert_equal "select.search-field", wrapper["data-select-dropdown-selector-value"]
    assert_nil page.find_link("Advanced search")["data-blacklight-modal"]
  end

  test "the real query input keeps the query, so the form works without JavaScript" do
    render_banner("/catalog?q=art")

    assert_selector "input[name=q][value=art]"
  end

  test "the advanced search link carries the current query as a first all-fields clause" do
    render_banner("/catalog?q=art&f[collection_ssim][]=Medical+History+Museum&page=3")

    href = page.find_link("Advanced search")[:href]
    assert_includes href, "/catalog/advanced"
    assert_includes href, "clause%5B0%5D%5Bfield%5D=all_fields"
    assert_includes href, "clause%5B0%5D%5Bquery%5D=art"
    assert_includes href, "Medical+History+Museum"
    assert_not_includes href, "page="
  end

  test "an existing clause, filter mode, range and sort also carry over to the advanced search link" do
    render_banner("/catalog?clause[0][field]=title&clause[0][query]=portrait&op=should&f[collection_ssim][]=A&f_inclusive[object_type_ssim][]=B&range[date_start_isi][begin]=1900&range[date_start_isi][end]=1950&sort=title")

    href = page.find_link("Advanced search")[:href]
    params = Rack::Utils.parse_nested_query(URI(href).query)

    assert_equal({ "0" => { "field" => "title", "query" => "portrait" } }, params["clause"])
    assert_equal "should", params["op"]
    assert_equal({ "collection_ssim" => [ "A" ] }, params["f"])
    assert_equal({ "object_type_ssim" => [ "B" ] }, params["f_inclusive"])
    assert_equal({ "date_start_isi" => { "begin" => "1900", "end" => "1950" } }, params["range"])
    assert_equal "title", params["sort"]
  end
end
