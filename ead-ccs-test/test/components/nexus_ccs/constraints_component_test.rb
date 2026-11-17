require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

# The pills above the results (NexusCcs::ConstraintsComponent)
class ConstraintsComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  STYLES = Rails.root.join("app/assets/stylesheets/components")
  GRAINGER = "Grainger Museum Collection"
  DENTAL = "Henry Forman Atkinson Dental Museum"

  def page = Capybara::Node::Simple.new(rendered_content)

  def render_for(params)
    # Blacklight builds a pill's remove link from the controller's search state (the request's parameters), so they go on the URL too
    with_controller_class(CatalogController) do
      with_request_url("/catalog?#{params.to_query}") do
        state = Blacklight::SearchState.new(params.with_indifferent_access, CatalogController.blacklight_config, vc_test_controller)
        render_inline(NexusCcs::ConstraintsComponent.new(search_state: state, inline: true))
      end
    end
  end

  def remove_link(value) = page.find(".applied-filter", text: value).find("a.remove")[:href]
  def collections_in(href) = Rack::Utils.parse_nested_query(URI(href).query).values_at("f", "f_inclusive").compact.flat_map { |f| Array(f["collection_ssim"]) }

  test "each collection chosen in a multi-select filter is a pill of its own, not one 'A OR B' pill" do
    render_for(f_inclusive: { collection_ssim: [ GRAINGER, DENTAL ] })

    assert_selector ".applied-filter", count: 2
    assert_selector ".applied-filter", text: GRAINGER
    assert_selector ".applied-filter", text: DENTAL
    assert_no_text " OR "
  end

  test "a pill's remove button takes off its own value and keeps the other" do
    render_for(f_inclusive: { collection_ssim: [ GRAINGER, DENTAL ] })

    assert_equal [ DENTAL ], collections_in(remove_link(GRAINGER))
    assert_equal [ GRAINGER ], collections_in(remove_link(DENTAL))
  end

  test "each pill's remove button is named for its own value" do
    render_for(f_inclusive: { collection_ssim: [ GRAINGER, DENTAL ] })

    [ GRAINGER, DENTAL ].each do |value|
      assert_match value, page.find(".applied-filter", text: value).find("a.remove").text
    end
  end

  test "a single value is still one pill" do
    render_for(f: { collection_ssim: [ GRAINGER ] })
    assert_selector ".applied-filter", count: 1
  end

  test "a pill shows its whole value: no truncation, a long one wraps" do
    css = STYLES.join("results_toolbar.css").read
    rule = css[/\.constraints-container \.applied-filter \.constraint-value \{[^}]+\}/]

    %w[max-width:\ none overflow:\ visible text-overflow:\ clip white-space:\ normal overflow-wrap:\ anywhere].each do |declaration|
      assert_includes rule, declaration
    end
  end

  test "the sort and page-size boxes are capped at 18rem even after the responsive rules" do
    responsive = STYLES.join("responsive.css").read
    general = responsive.index("#sortAndPerPage .search-widgets > * {")
    cap = responsive.index("#sortAndPerPage .search-widgets > :is(.sort-dropdown, .per_page-dropdown) {\n  max-width: min(18rem, 100%);")

    assert cap, "the cap is in responsive.css"
    assert_operator cap, :>, general, "the cap comes after the rule that set max-width: 100%"
  end
end
