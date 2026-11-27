# frozen_string_literal: true

require "test_helper"
require_relative "../support/env_override"
require_relative "../support/outages"

# The category picture pages, collection and named collection pages, themes and stories (docs/categories-themes-stories.md). Solr is
# not needed: the lists are given to the pages through the cache, as BrowsePagesTest does, and Solr being down is a test of its own.
class DiscoveryPagesTest < ActionDispatch::IntegrationTest
  include EnvOverride

  PICTURE = { "id" => "r1", "title" => "A print", "path" => "https://unimelbourne.widen.net/content/x/jpeg/a.jpeg", "width" => nil, "height" => nil }.freeze

  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @cache }

  def seed(slug, rows) = Rails.cache.write(SuppressedRecord.cache_key("categories/v1/#{slug}"), rows, expires_in: 1.day)

  def rows(count) = (1..count).map { |n| { "value" => "Value #{format('%03d', n)}", "count" => 1000 - n, "image" => (PICTURE if n == 1) } }

  def seed_showcase(fq, total: 12, docs: [])
    key = "showcase/v1/#{Digest::SHA256.hexdigest(Array(fq).join("\n"))}"
    Rails.cache.write(SuppressedRecord.cache_key(key), { "total" => total, "docs" => docs,
                                                         "facets" => { "object_type_ssim" => [ [ "Work", 9 ] ], "date_era_ssim" => [ [ "20th century", 12 ] ], "named_collection_ssim" => [] } })
  end

  test "a category page shows a card for each value, with its count, opening the search with that value as a filter" do
    seed("regions", [ { "value" => "Oceania", "count" => 8638, "image" => PICTURE }, { "value" => "Europe", "count" => 6840, "image" => nil } ])

    get "/browse/categories/regions"

    assert_response :success
    assert_select "h1", "Regions"
    assert_select "article.explore-card", count: 2
    assert_select "article.explore-card h3 a[href*='f%5Bregion_ssim%5D%5B%5D=Oceania'][href*='any_assets=1']", text: "Oceania (8,638)"
    assert_select "article.explore-card img[src*='unimelbourne.widen.net']", count: 1
    assert_select "nav[aria-label='Sort categories'] a[aria-current='page']", text: "Most records"
  end

  test "a category page sorts A to Z and pages 48 cards at a time" do
    seed("materials", rows(50).reverse + [ { "value" => "aardvark hide", "count" => 1, "image" => nil } ])

    get "/browse/categories/materials", params: { sort: "az" }
    assert_equal "Aardvark hide (1)", css_select("article.explore-card h3").first.text.squish
    assert_select "article.explore-card", count: Categories::PER_PAGE
    assert_select "nav[aria-label='Sort categories'] a[aria-current='page']", text: "A to Z"

    get "/browse/categories/materials", params: { page: 2 }
    assert_select "article.explore-card", count: 3
    assert_select "meta[name='robots'][content*='noindex']" # page 2 on is not indexed
  end

  test "an unknown category is not found, and with the index down and nothing kept the page says so" do
    get "/browse/categories/nonsense"
    assert_response :not_found

    Outages::SolrDown.active = true
    get "/browse/categories/eras"
    assert_response :service_unavailable
    assert_select "h1", "This page cannot be shown right now"
  ensure
    Outages::SolrDown.active = false
  end

  test "the categories page lists every way of grouping, each with a link to its page" do
    Categories.all.each { |dimension| seed(dimension.slug, rows(5)) }

    get "/browse/categories"

    assert_response :success
    Categories.all.each { |dimension| assert_select "section.categories-#{dimension.slug} a.explore__all[href='/browse/categories/#{dimension.slug}']" }
    assert_select "section.categories-eras article.explore-card", count: 4
  end

  test "a collection page has the placeholder introduction, its highlights, links that narrow its search, and its records in the search" do
    seed("collections", [ { "value" => "Grainger Museum Collection", "count" => 12, "image" => nil } ])
    seed_showcase([ 'collection_ssim:("Grainger Museum Collection")' ])
    slug = Browse::Slug.build("collections", "Grainger Museum Collection")

    get "/browse/collections/#{slug}"

    assert_response :success
    assert_select "h1", "Grainger Museum Collection"
    assert_select "[data-placeholder-wording]", text: /Lorem ipsum/
    assert_select "a.btn[href*='f%5Bcollection_ssim%5D%5B%5D=Grainger+Museum+Collection']", text: "See all 12 records"
    assert_select ".browse-facts__links a[href*='f%5Bobject_type_ssim%5D%5B%5D=Work']", text: "Work"
    assert_select "link[rel='canonical'][href$='/browse/collections/#{slug}']"

    get "/browse/collections/wrong-words-#{slug.split('-').last}"
    assert_redirected_to "/browse/collections/#{slug}"

    get "/browse/collections/grainger-0000000000"
    assert_response :not_found
  end

  test "the collections category page links each collection to its own page" do
    seed("collections", [ { "value" => "Grainger Museum Collection", "count" => 12, "image" => nil } ])

    get "/browse/categories/collections"

    assert_select "ul.category-landings a[href='/browse/collections/#{Browse::Slug.build('collections', 'Grainger Museum Collection')}']"
  end

  test "themes are listed, and a theme page shows its records and opens its search" do
    theme = Themes.find("grainger-in-the-1920s")
    seed_showcase(theme.fq)

    get "/themes"
    assert_response :success
    Themes.all.each { |each_theme| assert_select "a[href='/themes/#{each_theme.slug}']", text: each_theme.title }

    get "/themes/grainger-in-the-1920s"
    assert_response :success
    assert_select "h1", theme.title
    assert_select "a.btn[href*='range%5Bdate_start_isi%5D%5Bbegin%5D=1920'][href*='f%5Bcollection_ssim%5D']"

    get "/themes/no-such-theme"
    assert_response :not_found
  end

  test "stories are listed, and a story is shown with its text even when the index cannot answer" do
    Outages::SolrDown.active = true
    get "/stories"
    assert_response :success
    assert_select "a[href='/stories/example-story']"

    get "/stories/example-story"
    assert_response :success
    assert_select "h1", "Example story (placeholder)"
    assert_select ".story-page__text h2", text: "Lorem ipsum"
    assert_select ".story-page__text script", count: 0

    get "/stories/no-such-story"
    assert_response :not_found
  ensure
    Outages::SolrDown.active = false
  end

  test "the new pages are indexed with a canonical address, and are in the sitemap" do
    seed("collections", [ { "value" => "Grainger Museum Collection", "count" => 12, "image" => nil }, { "value" => "Tiny", "count" => 2, "image" => nil } ])
    seed("regions", rows(2))
    with_env("SEO_INDEXING" => "on") do
      get "/browse/categories/regions", params: { sort: "az" }
      assert_select "meta[name='robots']:not([content*='noindex'])"
      assert_select "link[rel='canonical'][href='http://www.example.com/browse/categories/regions']"

      Rails.cache.write(SuppressedRecord.cache_key("sitemap/records/v1"), []) # the record pages, as if already listed
      get "/sitemaps/1.xml"
    end

    assert_response :success
    %w[/browse/categories /browse/categories/regions /themes /themes/grainger-in-the-1920s /stories /stories/example-story].each do |path|
      assert_includes response.body, "<loc>http://www.example.com#{path}</loc>", path
    end
    assert_includes response.body, "/browse/collections/#{Browse::Slug.build('collections', 'Grainger Museum Collection')}"
    assert_not_includes response.body, Browse::Slug.build("collections", "Tiny") # fewer than 5 records
  end

  test "the header's Browse menu opens the browse page, categories, themes and stories; My saved items explains saving" do
    get "/stories"

    assert_select "#site-nav-browse a[href='/browse']"
    %w[/browse/categories /themes /stories].each { |path| assert_select "#site-nav-browse li a[href='#{path}']" }
    assert_select "#site-nav-saved a[href='/lists#how-saving-works']", text: "How saving and sharing work"
  end

  test "the lists page explains Save, Add to list and shared galleries" do
    get "/lists"

    assert_select "section#how-saving-works h2", "How saving and sharing work"
    assert_select "#how-saving-works ol li", count: 3
  end
end
