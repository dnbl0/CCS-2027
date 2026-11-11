require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

# The search results layout follows Europeana's (sidebar on the left): see components/results_layout.css.
class ResultsLayoutTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  Presenter = Struct.new(:document)
  STYLES = Rails.root.join("app/assets/stylesheets/components")

  def page = Capybara::Node::Simple.new(rendered_content)

  def config = CatalogController.blacklight_config

  def card(fields) = NexusCcs::ResultCardComponent.new(document: Presenter.new(SolrDocument.new(fields)))

  test "the sidebar is a 320px column at the page container's left edge, ruled on its right; the results have 32px sides" do
    css = STYLES.join("results_layout.css").read

    assert_includes css, "--sidebar-width: 20rem;"
    assert_includes css, "--content-gutter: 2rem;"
    assert_match(/body\.blacklight-catalog-index #content \{\s+padding: var\(--ccs-space-4\) var\(--content-gutter\) var\(--ccs-space-8\);/, css)
    assert_match(/@media \(min-width: 992px\) \{\s+#main-container > \.row \{\s+flex-wrap: nowrap;/, css)
    assert_includes css, "border-right: 1px solid var(--ccs-border-panel);"
    assert_match(/body\.blacklight-catalog-index #main-container \{\s+padding-inline: 0;/, css)
  end

  test "the results page has no maximum width, on the main container or the search banner; 16px gutters on a phone" do
    css = STYLES.join("results_layout.css").read

    assert_match(/body\.blacklight-catalog-index #main-container \{\s+width: 100%;\s+max-width: none;\s+margin-inline: 0;\s+padding-inline: 0;/, css)
    assert_match(/body\.blacklight-catalog-index \.search-banner__inner \{\s+max-width: none;/, css)
    assert_match(/@media \(max-width: 768px\) \{\s+body\.blacklight-catalog-index #content \{\s+padding-inline: var\(--space-16\);/, css)
  end

  test "mosaic columns step with the width, with 24px gutters, and keep growing on a wide window" do
    css = STYLES.join("results_layout.css").read
    columns = css.scan(/@media \(min-width: (\d+)px\) \{\s+\.documents-masonry \{ --result-columns: repeat\((\d+), 1fr\); \}/)
    steps = columns.map { |width, count| [ width.to_i, count.to_i ] }

    assert_equal [ [ 632, 2 ], [ 928, 3 ], [ 992, 2 ], [ 1264, 3 ], [ 1560, 4 ], [ 1856, 5 ], [ 2152, 6 ] ], steps
    assert_equal 4, steps.reverse.find { |width, _| width <= 1600 }.last
    assert_includes css, "--results-gutter: 1.5rem;"
  end

  test "the columns are the number of 17rem tiles that fit beside the 320px sidebar and the side padding" do
    css = STYLES.join("results_layout.css").read
    steps = css.scan(/min-width: (\d+)px\) \{\s+\.documents-masonry \{ --result-columns: repeat\((\d+)/).map { |w, n| [ w.to_i, n.to_i ] }

    steps.each do |width, count|
      content = width >= 992 ? width - 320 - 64 : width - 64
      fits = ((content + 24) / (272 + 24)).floor
      assert_equal fits, count, "at #{width}px #{fits} columns fit"
    end
  end

  test "the mosaic's layout polyfill reads plain repeat(N, 1fr) from the shared variable" do
    css = STYLES.join("results_layout.css").read
    assert_match(/\.documents-masonry \{\s+grid-template-columns: var\(--result-columns\);/, css)
    assert_no_match(/auto-fill/, css.gsub(%r{/\*.*?\*/}m, ""), "auto-fill breaks the polyfill")
  end

  test "below 992px the sidebar is a drawer that slides from the left, 352px at most and 88vw at most" do
    css = STYLES.join("filter_drawer.css").read

    drawer = css[/@media \(max-width: 991\.98px\) \{.*?\n  #sidebar \{(.*?)\n  \}/m, 1]

    assert_includes drawer, "position: fixed;"
    assert_includes drawer, "inset: 0 auto 0 0;" # the left edge
    assert_includes drawer, "z-index: 1050;"
    assert_includes drawer, "width: 22rem;"
    assert_includes drawer, "max-width: 88vw;"
    assert_includes drawer, "transform: translateX(-100%);"
    assert_includes css, "background: var(--ccs-scrim);" # the navy modal blanket
  end

  test "the filter sidebar, toggle and list card are registered with Blacklight" do
    assert_equal NexusCcs::FilterSidebarComponent, config.index.sidebar_component
    assert_equal NexusCcs::ResultCardComponent, config.view.list.document_component
    assert_equal NexusCcs::FilterToggleComponent, config.index.collection_actions[:filters_toggle].component
  end

  test "the card is the CCS UI card image, or card no media when the record has no digital asset" do
    with_image = card("thumbnail_path_ssi" => "/digital-assets/thumbs/a.jpg", "title_tsim" => [ "Untitled" ])
    without = card("title_tsim" => [ "Untitled" ])

    assert with_image.media?
    assert_equal "media", with_image.variant
    assert_not without.media?
    assert_equal "no-media", without.variant
  end

  test "a card keeps its thumbnail for an open or view-only record, and drops it (and its path) for a request record" do
    thumb = "/digital-assets/thumbs/a.jpg"
    fields = { "thumbnail_path_ssi" => thumb, "title_tsim" => [ "Untitled" ] }

    assert card(fields.merge("licence_type_ssim" => [ "Public domain - Copyright expired" ])).media?
    assert card(fields.merge("licence_type_ssim" => [ "Copyright - Current" ])).media?
    assert card(fields).media?, "no licence is view-only"
    withheld = card(fields.merge("licence_type_ssim" => [ "ICIP Rights" ]))
    assert_not withheld.media?
    assert_equal "no-media", withheld.variant
    assert_nil withheld.media_path
  end

  test "the card heading is an h3" do
    assert_equal :h3, NexusCcs::ResultCardComponent::TITLE_TAG
    assert_equal :h3, card("title_tsim" => [ "Untitled" ]).instance_variable_get(:@title_component)
  end

  test "the card's three lines are the creator, the object type and the collection, whichever the record has" do
    full = card("creator_ssim" => [ "Purdie, Shirley" ], "object_type_ssim" => [ "painting" ], "collection_ssim" => [ "Medical History Museum" ])
    sparse = card("collection_ssim" => [ "Medical History Museum" ])

    assert_equal [ "Purdie, Shirley", "painting", "Medical History Museum" ], full.lines
    assert_equal [ "Medical History Museum" ], sparse.lines
  end

  test "the Filters button says how many filters are applied" do
    with_controller_class(CatalogController) do
      with_request_url("/catalog?q=skull&f[collection_ssim][]=A&f[object_type_ssim][]=B&f[object_type_ssim][]=C") do
        render_inline(NexusCcs::FilterToggleComponent.new)
      end
    end

    assert_selector "button.filters-toggle.d-lg-none[aria-haspopup=dialog][data-controller=filter-toggle]", text: "Filters"
    assert_selector ".filters-toggle__count", text: "2 applied" # two facets, not three values
  end

  test "the Filters button shows no count when nothing is applied" do
    with_controller_class(CatalogController) do
      with_request_url("/catalog?q=skull") { render_inline(NexusCcs::FilterToggleComponent.new) }
    end

    assert_selector "button.filters-toggle"
    assert_no_selector ".filters-toggle__count"
  end

  def render_constraints(url:, total:, inline: true)
    with_controller_class(CatalogController) do
      with_request_url(url) do
        vc_test_controller.instance_variable_set(:@response, Struct.new(:total).new(total))
        render_inline(NexusCcs::ConstraintsComponent.new(search_state: Blacklight::SearchState.new(Rack::Utils.parse_nested_query(URI(url).query).with_indifferent_access, config, vc_test_controller), inline: inline))
      end
    end
  end

  test "the toolbar line is the count and 'for' with the search as a pill" do
    render_constraints(url: "/catalog?q=art", total: 1234)

    assert_selector ".constraints-label", text: "1,234 results for"
    assert_selector ".applied-filter.query", text: "art"
    assert_no_selector ".catalog_startOverLink"
  end

  test "with nothing applied the line is just the count, and a single result is singular" do
    render_constraints(url: "/catalog?q=", total: 1)
    assert_selector ".constraints-label", text: "1 result", exact_text: true
  end

  test "the page-header copy of the constraints renders nothing, so it appears once" do
    render_constraints(url: "/catalog?q=art", total: 5, inline: false)
    assert_no_selector ".constraints-container"
  end

  test "the sidebar leads with 'Search filters (n)', with no Advanced filters link (it is in the banner)" do
    response = Blacklight::Solr::Response.new({ "response" => { "docs" => [], "numFound" => 0 } }, {})
    with_controller_class(CatalogController) do
      with_request_url("/catalog?q=art&f[collection_ssim][]=A") do
        render_inline(NexusCcs::FilterSidebarComponent.new(blacklight_config: config, response: response, view_config: config.index))
      end
    end

    assert_no_link "Advanced filters"
    assert_selector ".filter-sidebar__heading", text: "Search filters (1)"
    assert_selector "[data-controller~=filter-drawer] .filter-drawer__close"
  end

  test "a skeleton replaces the results and filter values while a search page loads" do
    css = STYLES.join("skeleton.css").read
    assert_includes STYLES.join("../application.css").read, "components/skeleton.css"
    %w[#documents\ .document .facet-values\ li].each { |selector| assert_includes css, ".is-searching #{selector}" }
    assert_includes css, "prefers-reduced-motion: reduce"
    assert_includes Rails.root.join("config/importmap.rb").read, 'pin "search_loading"'
    assert_includes Rails.root.join("app/javascript/search_loading.js").read, "is-searching"
  end

  test "facets are Blacklight's own: no custom facet field or item components" do
    config.facet_fields.each_value { |facet| assert_equal Blacklight::Facets::ItemComponent, facet.item_component, facet.key }
    assert_not defined?(NexusCcs::FacetFieldComponent)
    assert_not defined?(NexusCcs::FacetItemComponent)
  end

  test "the toolbar: even pill gaps, equal flexible selects, a two-row grid with full labels on phones" do
    css = STYLES.join("results_toolbar.css").read
    assert_match(/\.constraints-container \.applied-filter \{\s+margin: 0 !important;/, css) # not Bootstrap's mx-1
    assert_match(/\.sort-dropdown,\s+#sortAndPerPage \.per_page-dropdown \{\s+flex: 1 1 0;[^}]*max-width: 18rem;/m, css)
    phone = css[/@media \(max-width: 767\.98px\) \{.*?\n\}\n/m]
    assert_includes phone, "grid-template-columns: repeat(2, minmax(0, 1fr));"
    assert_includes phone, ".sort-dropdown .dropdown-toggle .d-none"
    assert_includes css, "#sortAndPerPage .per_page-dropdown .dropdown-toggle .visually-hidden {" # the words show at every width
    assert_includes phone, ".per_page-dropdown .dropdown-toggle .per-page__results" # and "results" goes on phones
  end
end
