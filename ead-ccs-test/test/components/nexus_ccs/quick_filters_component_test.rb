require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

# The one-tap filters above the results (NexusCcs::QuickFiltersComponent): the most useful values of era, object type and collection
# for the results on the page, from the facet counts the page already has (no extra request). The era values are stubbed: a local core
# may not have the field.
class QuickFiltersComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  def page = Capybara::Node::Simple.new(rendered_content)

  def facets(era: [], type: [], collection: [])
    { "date_era_ssim" => era.flatten, "object_type_ssim" => type.flatten, "collection_ssim" => collection.flatten }
  end

  def response_for(total:, facet_fields:)
    body = { "responseHeader" => { "params" => {} }, "response" => { "numFound" => total, "start" => 0, "docs" => [] },
             "facet_counts" => { "facet_fields" => facet_fields, "facet_queries" => {}, "facet_ranges" => {} } }
    Blacklight::Solr::Response.new(body, {}, blacklight_config: CatalogController.blacklight_config)
  end

  def render_for(params, total:, facet_fields:)
    with_controller_class(CatalogController) do
      with_request_url("/catalog?#{params.to_query}") do
        state = Blacklight::SearchState.new(params.with_indifferent_access, CatalogController.blacklight_config, vc_test_controller)
        render_inline(NexusCcs::QuickFiltersComponent.new(response: response_for(total: total, facet_fields: facet_fields), search_state: state))
      end
    end
  end

  def links = page.all("ul.quick-filters__list li a").map(&:text).map(&:squish)

  test "a list of links, labelled, mixing the top values of era, object type and collection, at most eight" do
    render_for({ q: "portrait" }, total: 200, facet_fields: facets(
      era: [ "20th century", 90, "19th century", 60, "18th century", 10 ],
      type: [ "photograph", 80, "painting", 40, "print", 30, "drawing", 20 ],
      collection: [ "University Art Collection", 100, "Grainger Museum Collection", 70, "Archives", 5 ]
    ))

    assert_selector "nav.quick-filters[aria-labelledby=quick-filters-heading] h2#quick-filters-heading", text: "Narrow these results"
    assert_equal 8, links.size
    assert_equal "20th century 90 results", links.first
    assert_includes links, "photograph 80 results"
    assert_includes links, "University Art Collection 100 results"
    href = page.find("a", text: "photograph")[:href]
    query = Rack::Utils.parse_nested_query(URI(href).query)
    assert_equal "portrait", query["q"]
    assert_equal [ "photograph" ], query.dig("f_inclusive", "object_type_ssim") || query.dig("f", "object_type_ssim")
    assert_selector "a .visually-hidden", text: /results/
  end

  test "a value every result has is not offered, nor a field already chosen from (another value would widen the results)" do
    render_for({ q: "portrait", f_inclusive: { object_type_ssim: [ "painting" ] } }, total: 40, facet_fields: facets(
      type: [ "painting", 40, "print", 3 ], collection: [ "University Art Collection", 40, "Archives", 2 ], era: [ "20th century", 12 ]
    ))

    assert_equal [ "20th century 12 results", "Archives 2 results" ], links
  end

  test "nothing when fewer than two values would help, and nothing for no results or a page without these facets" do
    render_for({ q: "x" }, total: 10, facet_fields: facets(type: [ "print", 3 ]))
    assert_no_selector ".quick-filters"

    render_for({ q: "x" }, total: 0, facet_fields: facets)
    assert_no_selector ".quick-filters"

    render_for({ q: "x" }, total: 50, facet_fields: {})
    assert_no_selector ".quick-filters"
  end
end
