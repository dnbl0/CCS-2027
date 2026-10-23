require "test_helper"

class PagesTest < ActionDispatch::IntegrationTest
  test "Browse collections is gone: its address goes to the collection cards on the home page" do
    get "/collections"

    assert_response :moved_permanently
    assert_redirected_to "/#browse-collections"
    follow_redirect!
    assert_select "#browse-collections"
  end

  test "the collection landing pages are gone: their addresses go to the results filtered to that collection" do
    YAML.load_file(Rails.root.join("config/pages.yml")).fetch("collections").each_key do |slug|
      facet_value = NexusCcs::SiteNavigation.facet_value(slug)
      get "/collections/#{slug}"

      assert_response :moved_permanently, slug
      assert_redirected_to "/catalog?#{{ f: { collection_ssim: [ facet_value ] }, search_field: "all_fields" }.to_query}"
    end
  end

  test "the collection links go to the results filtered to that collection" do
    get "/"
    NexusCcs::SiteNavigation.collections.each do |_label, facet_value, _slug|
      assert_select ".home-card__link[href=?]", "/catalog?#{{ f: { collection_ssim: [ facet_value ] }, search_field: "all_fields" }.to_query}"
    end
  end

  test "the record pages have Blacklight's Cite page but not its Email or SMS pages" do
    routes = Rails.application.routes
    assert_equal "/catalog/emu-1/citation", routes.url_helpers.citation_solr_document_path("emu-1")
    %w[email sms].each do |action|
      assert_not routes.named_routes.key?(:"#{action}_solr_document"), action
      assert_not routes.named_routes.key?(:"#{action}_solr_documents"), action
      get "/catalog/emu-1/#{action}"

      assert_response :not_found, action
    end
  end

  test "an unknown collection is not found" do
    get "/collections/unknown"

    assert_response :not_found
  end

  test "the help page has a section for each topic, with the jump navigation beside them" do
    get "/help"

    assert_response :success
    assert_select "body.page-help h1", "Help and support"
    assert_select ".cta-band", count: 0 # a "Still need help?" band only looped back to this page
    assert_select ".help-layout__content section.help-section", count: HelpTopic.all.size
    HelpTopic.all.each do |topic|
      assert_select "section.help-section##{topic.key} h2.help-section__heading", topic.title
      assert_select "section.help-section##{topic.key} .help-section__description", count: 1
      assert_select "section.help-section##{topic.key} .help-section__item", minimum: 1
      assert_select "nav.jump-nav a.jump-nav__link[href='##{topic.key}']", topic.title
    end
    assert_select ".jump-nav__title", "On this page"
    assert_select "nav.jump-nav[data-controller=jump-nav] a.jump-nav__link[data-jump-nav-target=link]", count: HelpTopic.all.size
    assert_select ".side-nav", count: 0
    assert_select "p.help-intro", count: 1
  end

  test "the Contact Us section lists the collection contacts, and the Indigenous section links to the priorities" do
    get "/help"

    assert_select "#contact-us .help-section__contact", minimum: 5
    assert_select "#contact-us a[href^=mailto]", minimum: 3
    assert_select "#indigenous a[href='https://www.unimelb.edu.au/murmuk-djerring']"
  end

  test "the old help topic links go to the topic's section" do
    { "faq" => "/help#faq", "copyright" => "/help#copyright", "access" => "/help#contact-us", "contact-us" => "/help#contact-us", "indigenous" => "/help#indigenous" }.each do |topic, location|
      get "/help", params: { topic: topic }

      assert_redirected_to location
    end

    [ "nope", "privacy", "search-tips" ].each do |topic|
      get "/help", params: { topic: topic }
      assert_response :success
    end
  end

  test "the pages folded into Help redirect permanently to their section" do
    { "/contact" => "/help#contact-us", "/help/indigenous-data" => "/help#indigenous", "/help/search-tips" => "/help" }.each do |path, location|
      get path

      assert_redirected_to location
      assert_response :moved_permanently
    end
  end

  test "the about page is built on the help page's template, with an On this page sidebar" do
    get "/about"

    assert_response :success
    assert_select "body.page-help h1", "About Collections Navigator"
    assert_select "body.page-help .help-layout > nav.jump-nav[aria-labelledby='jump-nav-title'] .jump-nav__link", count: 5
    assert_select "body.page-help .help-layout__content > section.help-section", count: 5
    css_select(".jump-nav__link").each { |link| assert_equal 1, css_select(link["href"]).size, "no section for #{link["href"]}" }
    assert_select "#contact-support, main a[href='/help#contact-us']", count: 0 # no Contact and support section; Help has the contact details
    assert_select ".site-nav a[href='/about']", count: 1
  end

  test "the header lists Browse records, About and Help in that order" do
    get "/about"

    labels = [ "Browse records", "About", "Help" ]
    items = css_select(".site-nav > ul > li").map { |item| item.text.squish }
    assert_equal labels, items.first(3).map { |text| labels.find { |label| text.start_with?(label) } }
    assert_select "#site-nav a[href='https://about.unimelb.edu.au']", count: 0
  end

  test "the site header links to the pages, and has no Contact page of its own" do
    get "/help"

    assert_select "#site-nav-records li a[href^='/catalog?f%5Bcollection_ssim%5D']", count: 5
    assert_select "#site-nav-collections", count: 0
    assert_select "#site-nav a[href='/collections']", count: 0
    assert_select "#site-nav-help a[href='/help#faq']"
    assert_select "#site-nav-help li a", count: HelpTopic.all.size
    assert_select "#site-nav a[href='/contact']", count: 0
    assert_select "a.site-header__title[href='/']"
  end

  test "every content page has one main landmark for the skip link," do
    paths = [ "/", "/help", "/about" ]

    paths.each do |path|
      get path

      assert_response :success, path
      assert_select "a.skip-link[href='#main-content']", count: 1
      assert_select "main#main-content", count: 1
    end
  end

  test "the Acknowledgement of Country advisory is body text colour, not the pale secondary colour" do
    get "/"

    assert_select "#country-acknowledgement p.text-body-secondary"
    assert_select "#country-acknowledgement .text-secondary", count: 0
  end
end
