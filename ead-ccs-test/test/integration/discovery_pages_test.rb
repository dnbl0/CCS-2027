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
    key = "showcase/v1/#{Digest::SHA256.hexdigest((Array(fq) + [ Showcase::PAGE_HIGHLIGHTS ]).join("\n"))}" # a page asks for its 16 highlights
    Rails.cache.write(SuppressedRecord.cache_key(key), { "total" => total, "docs" => docs,
                                                         "facets" => { "object_type_ssim" => [ [ "Work", 9 ] ], "date_era_ssim" => [ [ "20th century", 12 ] ], "named_collection_ssim" => [] } })
  end

  def seed_hub(slug, values) = Rails.cache.write(SuppressedRecord.cache_key("browse_hubs/v1/#{slug}"), values, expires_in: 1.day)

  def seed_wall(slug, entries) = Rails.cache.write(SuppressedRecord.cache_key("browse_cards/v3/#{slug}/wall/v2"), entries, expires_in: 1.day)

  test "a category page is on the one Browse template: its title, All and A–Z as tabs, a mosaic of its values opening the search" do
    seed_hub("classifications", [ [ "Prints", 8638 ], [ "Paintings", 6840 ] ])
    seed_wall("classifications", [ { "label" => "Prints", "count" => 8000, "total" => 8638, "image" => PICTURE } ])

    get "/browse/classifications"

    assert_response :success
    assert_select "h1.places-page__title", "Classifications"
    assert_select "nav.places-views a.places-views__link", count: 2
    assert_select "nav.places-views a.places-views__link[aria-current=page]", "All"
    assert_select ".mosaic-flow article.explore-card h3 a[href*='f%5Bclassification_ssim%5D%5B%5D=Prints'][href*='any_assets=1']", text: "Prints"
    assert_select ".mosaic-flow article.explore-card .explore-card__intro", 0 # no counts

    get "/browse/classifications", params: { view: "az" }
    assert_equal [ "Prints", "Paintings" ], css_select("a.places-list__link").map { |a| a.text.squish }
    assert_select "nav.places-views a.places-views__link[aria-current=page]", "A–Z"
  end

  test "the collections page links each collection to its own page, from the mosaic and the A–Z list" do
    seed_hub("collections", [ [ "Grainger Museum Collection", 12 ] ])
    seed_wall("collections", [ { "label" => "Grainger Museum Collection", "count" => 12, "image" => PICTURE } ])
    own = "/browse/collections/#{Browse::Slug.build('collections', 'Grainger Museum Collection')}"

    get "/browse/collections"
    assert_select ".mosaic-flow article.explore-card h3 a[href='#{own}']"

    get "/browse/collections", params: { view: "az" }
    assert_select "a.places-list__link[href='#{own}']"
  end

  test "an unknown category is not found, and with the index down and nothing kept the page says so on the same template" do
    get "/browse/nonsense"
    assert_response :not_found

    Outages::SolrDown.active = true
    get "/browse/materials"
    assert_response :service_unavailable
    assert_select "h1", "Materials"
    assert_select ".browse__unavailable a", "search all records"
  ensure
    Outages::SolrDown.active = false
  end

  test "the Browse page has a section for each way in, each linking to its one page; the old addresses answer 301" do
    Categories.all.each { |dimension| seed(dimension.slug, rows(5)) }

    get "/browse"

    assert_response :success
    { "collections" => "/browse/collections", "object-types" => "/browse/object-types", "classifications" => "/browse/classifications",
      "materials" => "/browse/materials", "regions" => "/browse/places", "eras" => "/browse/time", "named-collections" => "/browse/named-collections" }.each do |slug, path|
      assert_select "section.browse-#{slug} a.home-section__link[href='#{path}']"
    end
    assert_select "section.browse-regions h2", "Places"
    assert_select "section.browse-eras h2", "Time"
    assert_select "section.browse-eras article.explore-card", count: 5 # too few pictures for its carousel: its first cards, up to eight
    # the other ways in, Discover among them (it had no link since the home page's Featured and trending section went)
    assert_select "section.browse-more a.browse-more__link[href='/browse/colours']", "Explore by colour"
    assert_select "section.browse-more a.browse-more__link[href='/browse/discover']"

    { "/browse/categories" => "/browse", "/browse/categories/regions" => "/browse/places", "/browse/categories/eras" => "/browse/time",
      "/browse/categories/object-types" => "/browse/object-types", "/browse/categories/materials?sort=az" => "/browse/materials?sort=az",
      "/explore/colours?colour=teal" => "/browse/colours?colour=teal", "/browse/periods" => "/browse/time", "/collections" => "/browse/collections",
      "/saved_searches" => "/saved-searches", "/search_history" => "/search-history" }.each do |old, new|
      get old
      assert_redirected_to new
      assert_response :moved_permanently
    end
  end

  # rows each with a picture of its own (a different file each, so none is a repeat); eras named so their time order differs from their counts
  def pictured(slug, count)
    (1..count).map do |n|
      value = slug == "eras" ? "#{count - n + 1}th century" : "#{slug} #{n}"
      { "value" => value, "count" => 1000 - n, "image" => PICTURE.merge("id" => "#{slug}-#{n}", "path" => "https://unimelbourne.widen.net/content/x/jpeg/#{slug}-#{n}.jpeg?w=600") }
    end
  end

  test "the Browse page on the home page's layouts: stacks, clusters and the eras' carousel, two on bands of colour, no picture twice" do
    Categories.all.each { |dimension| seed(dimension.slug, pictured(dimension.slug, 9)) }

    get "/browse"

    assert_select "main.categories-page > section.home-section.browse-section", Categories.all.size + 1 # and More ways in
    assert_select "section.browse-object-types.home-section--tinted ul.stack:not(.stack--bare) li.stack__item", 5
    assert_select "section.browse-classifications ul.cluster[data-count='4'] li", 4
    assert_select "section.browse-materials ul.stack.stack--bare li.stack__item", 4
    assert_select "section.browse-regions ul.stack li.stack__item", 5
    assert_select "section.browse-collections.home-section--tinted ul.cluster[data-count='4']"
    assert_select "section.browse-named-collections ul.stack li.stack__item", 5
    # the eras: the eight with the most records, as slides in time order
    eras = css_select("section.browse-eras .feature-carousel__slide h3").map { |title| title.text.strip }
    assert_equal %w[2th 3th 4th 5th 6th 7th 8th 9th].map { |n| "#{n} century" }, eras
    assert_select "section.browse-eras [aria-roledescription=carousel][aria-label='The eras, earliest first']"
    pictures = css_select("main img").map { |img| img["src"][%r{[^/?]+\.jpeg}] }
    assert_equal pictures.uniq, pictures, "no picture twice"
  end

  test "a collection page has the placeholder introduction, its highlights, links that narrow its search, and its records in the search" do
    seed("collections", [ { "value" => "Grainger Museum Collection", "count" => 12, "image" => nil } ])
    seed_showcase([ 'collection_ssim:("Grainger Museum Collection")' ])
    slug = Browse::Slug.build("collections", "Grainger Museum Collection")

    get "/browse/collections/#{slug}"

    assert_response :success
    assert_select "h1", "Grainger Museum Collection"
    assert_select "[data-placeholder-wording]", text: /Lorem ipsum/
    assert_select "a.btn[href*='f%5Bcollection_ssim%5D%5B%5D=Grainger+Museum+Collection']", text: "See all its records"
    assert_select ".place-section a[href*='f%5Bobject_type_ssim%5D%5B%5D=Work']", text: /\AWork/ # a tile, or a link where it has no picture
    assert_select "link[rel='canonical'][href$='/browse/collections/#{slug}']"

    get "/browse/collections/wrong-words-#{slug.split('-').last}"
    assert_redirected_to "/browse/collections/#{slug}"

    get "/browse/collections/grainger-0000000000"
    assert_response :not_found
  end

  test "themes are listed on the Stories page (the old /themes answers 301 to it), and a theme page shows its records and opens its search" do
    theme = Themes.find("grainger-in-the-1920s")
    seed_showcase(theme.fq)

    get "/themes"
    assert_redirected_to "/browse/stories#themes"
    get "/browse/stories"
    assert_response :success
    assert_select "section#themes h2", "Themes"
    Themes.all.each { |each_theme| assert_select "a[href='/browse/themes/#{each_theme.slug}']", text: each_theme.title }

    get "/browse/themes/grainger-in-the-1920s"
    assert_response :success
    assert_select "h1", theme.title
    assert_select "a.btn[href*='range%5Bdate_start_isi%5D%5Bbegin%5D=1920'][href*='f%5Bcollection_ssim%5D']"

    get "/browse/themes/no-such-theme"
    assert_response :not_found
  end

  test "stories are listed, and a story is shown with its text even when the index cannot answer" do
    Outages::SolrDown.active = true
    get "/browse/stories"
    assert_response :success
    assert_select "a[href='/browse/stories/example-story']"

    get "/browse/stories/example-story"
    assert_response :success
    assert_select "h1", "Example story (placeholder)"
    assert_select ".story__text h2", text: "Lorem ipsum"
    assert_select ".story__text script", count: 0

    get "/browse/stories/no-such-story"
    assert_response :not_found
  ensure
    Outages::SolrDown.active = false
  end

  test "the new pages are indexed with a canonical address, and are in the sitemap" do
    seed("collections", [ { "value" => "Grainger Museum Collection", "count" => 12, "image" => nil }, { "value" => "Tiny", "count" => 2, "image" => nil } ])
    seed("classifications", rows(2))
    with_env("SEO_INDEXING" => "on") do
      get "/browse/classifications", params: { sort: "az" }
      assert_select "meta[name='robots']:not([content*='noindex'])"
      assert_select "link[rel='canonical'][href='http://www.example.com/browse/classifications']"

      Rails.cache.write(SuppressedRecord.cache_key("sitemap/records/v1"), []) # the record pages, as if already listed
      get "/sitemaps/1.xml"
    end

    assert_response :success
    %w[/browse/classifications /browse/time /browse/places /browse/colours /browse/stories].each do |path|
      assert_includes response.body, "<loc>http://www.example.com#{path}</loc>", path
    end
    assert_includes response.body, "/browse/collections/#{Browse::Slug.build('collections', 'Grainger Museum Collection')}"
    assert_not_includes response.body, Browse::Slug.build("collections", "Tiny") # fewer than 5 records
    assert_not_includes response.body, "/browse/themes/grainger-in-the-1920s" # placeholder wording: kept out until it is written
    assert_not_includes response.body, "/browse/categories"
  end

  test "the header's Browse menu opens the browse page and every way in, in the Browse page's order; Saved explains saving and compares" do
    get "/browse/stories"

    assert_select "#site-nav-browse a[href='/browse']"
    expected = %w[/browse/collections /browse/object-types /browse/classifications /browse/places /browse/time /browse/colours /browse/makers /browse/subjects /browse/stories] # one Stories item holds the stories and the themes
    assert_equal expected, css_select("#site-nav-browse li a").map { |link| link["href"] }
    assert_select "#site-nav-saved a[href='/compare']", text: "Compare images"
    assert_select "#site-nav-saved a[href='/search-history']"
    assert_select "#site-nav-saved a[href='/lists#how-saving-works']", text: "How saving and sharing work"
  end

  test "the lists page explains Save, Add to list and shared galleries" do
    get "/lists"

    assert_select "section#how-saving-works h2", "How saving and sharing work"
    assert_select "#how-saving-works ol li", count: 3
  end
end
