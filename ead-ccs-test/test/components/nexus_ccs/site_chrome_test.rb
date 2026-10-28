require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

class SiteChromeTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  def page
    Capybara::Node::Simple.new(rendered_content)
  end

  def render_header(url: "/catalog?q=skull", action: "index")
    with_controller_class(CatalogController) do
      with_request_url(url) do
        vc_test_controller.action_name = action
        render_inline(NexusCcs::HeaderComponent.new(blacklight_config: CatalogController.blacklight_config))
      end
    end
  end

  test "header has the audience links, search toggle and a Search collections menu that links to the collection pages" do
    render_header

    assert_selector "header.site-header"
    assert_selector ".site-header__utility nav a", count: NexusCcs::SiteNavigation::AUDIENCE.size
    assert_selector "button.site-header__search-toggle[aria-label='Open search']"
    assert_selector "#site-nav-records li a[href^='/catalog?any_assets=1&f%5Bcollection_ssim%5D']", count: NexusCcs::SiteNavigation.collections.size
    assert_selector "#search-overlay form[role=search]"
    assert_selector "#site-nav form[role=search]"
  end

  test "header has the Help menu: FAQ, Indigenous, Copyright, Access, and no Contact page link" do
    render_header

    assert_selector "#site-nav-help a[href='/help#faq']"
    assert_equal [ "/help#faq", "/help#indigenous", "/help#copyright", "/help#contact-us" ],
                 page.all("#site-nav-help ul a").map { |a| a[:href] }
    assert_no_link "Contact", href: "/contact"
  end

  test "header menu controls are wired to the site-header Stimulus controller" do
    render_header

    assert_selector "header[data-controller='site-header']"
    assert_selector "button.site-nav__trigger[aria-expanded='false'][data-action='site-header#toggleSection']", count: 2 # Search collections and Help
    assert_selector "button.site-header__menu[aria-controls='site-nav'][aria-expanded='false']"
    assert_selector "#site-nav-records button.site-nav__back"
  end

  test "search results show the breadcrumb and a banner with the search form" do
    render_header

    assert_selector "nav.breadcrumb-bar[aria-label=Breadcrumb] li[aria-current=page]", text: "Search results"
    assert_selector "section.search-banner .search-banner__title", text: "Search the Collection"
    assert_selector "section.search-banner form.search-banner__form"
    assert_no_selector "h1" # the banner title is not a heading: pages render their own h1
    assert_no_selector "nav.topbar" # Blacklight's own top navbar is replaced
  end

  test "Search all records opens the catalog on the All Fields search, and groups its links under three headings" do
    render_header(url: "/catalog")
    assert_selector "#site-nav-records a.site-nav__panel-title[href='/catalog?search_field=all_fields']", text: "Search all records"
    assert_selector "#site-nav-records .site-nav__group-title", count: 3
    assert_selector "#site-nav-group-collections + ul a", text: "Grainger Museum Collection"
    assert_selector "#site-nav-records ul[aria-labelledby='site-nav-group-types'] a", text: "Archives"
    assert_selector "#site-nav-records .site-nav__browse-more a", text: /\AAll( [\d,]+)? records\z/
    assert_selector "#site-nav-records .site-nav__browse-more a[href='/catalog/advanced']", text: "Advanced search"
  end

  test "the bare search page has no breadcrumb" do
    render_header(url: "/catalog")
    assert_no_selector "nav.breadcrumb-bar"
  end

  test "breadcrumb links every item but the last" do
    render_inline(NexusCcs::BreadcrumbComponent.new(items: [ [ "Search results", "/catalog" ], [ "A skull", nil ] ]))

    assert_selector "a[href='/catalog']", text: "Search results"
    assert_selector "li[aria-current=page]", text: "A skull"
    assert_no_selector "li[aria-current=page] a"
  end

  test "the saved-records bar is the last child of the breadcrumb strip, and nowhere else on a page with a breadcrumb" do
    render_header(url: "/catalog/abc", action: "show")

    assert_selector ".breadcrumb-strip > nav.breadcrumb-bar + a.site-nav__saved[href='/bookmarks']", count: 1
    assert_selector "a.site-nav__saved", count: 1
    assert_no_selector ".site-header .site-nav__saved"
    assert_no_selector ".site-nav__drawer-saved"
  end

  test "the saved-records bar says 0, 1 and 2 saved records, with the plus icon when empty" do
    { 0 => "0 saved records", 1 => "1 saved record", 2 => "2 saved records" }.each do |count, words|
      render_inline(NexusCcs::SavedBarComponent.new(count: count))
      assert_selector "a.site-nav__saved .site-nav__saved-text[role=status]", text: /\A\s*#{count}\s+#{words.sub(/\A\d+ /, "")}\s*\z/
      assert_selector "a.site-nav__saved.site-nav__saved--empty", count: count.zero? ? 1 : 0
      assert_selector "[data-role=bookmark-counter]", text: count.to_s
    end
  end

  test "the saved-records bar keeps the header top strip on a page with no breadcrumb" do
    render_header(url: "/catalog", action: "index")

    assert_no_selector ".breadcrumb-strip"
    assert_selector ".site-header__utility a.site-nav__saved--header", count: 1
  end

  test "the phone menu has the saved-records link only on a page with no breadcrumb strip" do
    render_header(url: "/catalog", action: "index")

    assert_selector "#site-nav li.site-nav__saved-item > a.site-nav__saved.site-nav__saved--drawer[href='/bookmarks']", count: 1
    assert_selector "#site-nav a.site-nav__saved--drawer .site-nav__saved-text", text: /saved record/
    assert_selector "a.site-nav__saved", count: 2 # the header's top strip (desktop) and the menu (phones)

    render_header(url: "/catalog/abc", action: "show")

    assert_no_selector ".site-nav__saved-item"
    assert_no_selector "a.site-nav__saved--drawer"
  end

  test "breadcrumb renders nothing without items" do
    render_inline(NexusCcs::BreadcrumbComponent.new(items: []))
    assert_no_selector "nav"
  end

  test "footer has the acknowledgement, links, social icons and identifiers" do
    render_inline(NexusCcs::SiteFooterComponent.new)

    assert_selector "footer.site-footer h2", text: "Acknowledgement of Country"
    assert_selector ".site-footer__links a", count: NexusCcs::SiteNavigation::FOOTER_ABOUT.size
    assert_selector ".site-footer__social a[aria-label]", count: NexusCcs::SiteNavigation::FOOTER_SOCIAL.size
    assert_selector ".site-footer__identifiers", text: "CRICOS: 00116K"
  end

  test "the search overlay searches the University of Melbourne website like the global search on unimelb.edu.au" do
    render_inline(NexusCcs::SearchOverlayComponent.new)

    assert_selector "#search-overlay form[role=search][method=get][action='https://search.unimelb.edu.au/s/search.html']"
    assert_selector "#search-overlay input[type=hidden][name=collection][value='uom~sp-global']", visible: :all
    assert_selector "#search-overlay-input[name=query][maxlength='255']"
    assert_selector "label[for=search-overlay-input]", text: "Search Melbourne University", visible: :all
    assert_no_selector ".search-overlay__recent"
  end
end
