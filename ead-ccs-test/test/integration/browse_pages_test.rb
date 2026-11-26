# frozen_string_literal: true

require "test_helper"
require_relative "../support/outages"

# The pages behind the home page's Explore tiles: every object type, place, period, maker and subject, each opening its records.
class BrowsePagesTest < ActionDispatch::IntegrationTest
  include Outages
  VALUES = [ [ "lyre", 120 ], [ "harp", 40 ], [ "bell", 3 ], [ "Étui", 1 ], [ "1973 print", 1 ] ].freeze

  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @cache }

  def seed(slug, values) = Rails.cache.write("browse_hubs/v1/#{slug}", values, expires_in: 1.day)

  # The cards of a hub as Browse::Cards keeps them (label, count, a picture, the description; a period has its years)
  def seed_cards(slug, entries) = Rails.cache.write(SuppressedRecord.cache_key("browse_cards/v4/#{slug}"), entries, expires_in: 1.day)

  def entry(label, **extra) = { "label" => label, "count" => 5, "intro" => "Includes prints. Held in University Art Collection.", "image" => nil }.merge(extra.transform_keys(&:to_s))

  test "the Browse page: makers and subjects as their hubs' cards, each section linking to its full list, and the other ways in last" do
    image = { id: "r1", title: "A print", path: "https://dam.example.org/a.jpg", width: nil, height: nil }
    seed_cards("makers", [ entry("Ramsay, Hugh", "image" => image) ] + (1..7).map { |number| entry("Maker #{number}") })
    seed_cards("subjects", [ entry("Portraits") ])

    get "/browse"

    assert_response :success
    assert_select "h1", "Browse the collections"
    { "makers" => "Makers", "subjects" => "Subjects" }.each do |slug, title|
      assert_select "section.browse-#{slug}[aria-labelledby='browse-#{slug}'] h2#browse-#{slug}", title
      assert_select "section.browse-#{slug} a.home-section__link[href='/browse/#{slug}']"
    end
    assert_select "section.browse-makers article.explore-card", count: 8
    assert_select "section.browse-makers .explore-card__intro", text: "Includes prints. Held in University Art Collection.", count: 8
    assert_select "section.browse-makers article.explore-card img[src*='dam.example.org']", count: 1
    assert_select "section.browse-more h2", "More ways in"
  end

  test "with nothing to show, a way in is left out and the page still answers" do
    with_solr_down { get "/browse" }

    assert_response :success
    assert_select "section.browse-makers", count: 0
    assert_select "section.browse-more h2", "More ways in"
  end

  test "a way in lists the most common values first, each opening all its records with its count" do
    seed("object-types", VALUES)

    get "/browse/object-types", params: { view: "az" } # every Browse page opens on "All", the mosaic; the list is "A–Z"

    assert_response :success
    assert_select "h1", "Object types"
    links = css_select("a.places-list__link").map { |a| a.text.squish }
    assert_equal [ "Lyre", "Harp", "Bell", "Étui", "1973 print" ], links # names only: the site shows no counts
    assert_select "a.places-list__link[href*='f%5Bobject_type_ssim%5D%5B%5D=lyre'][href*='any_assets=1']"
  end

  test "a letter shows the values that start with it, alphabetically, and says which letter it is" do
    seed("object-types", VALUES)

    get "/browse/object-types", params: { letter: "B" }

    assert_select "a.places-list__link", count: 1
    assert_select "a.places-list__link", text: /Bell/
    assert_select "nav.places-letters a[aria-current='page']", text: "B"
    assert_select "nav[aria-label='Browse by letter'] a", text: "Z", count: 0 # only letters that have records
  end

  test "a letter that does not exist is the default list, not an error" do
    seed("object-types", VALUES)

    get "/browse/object-types", params: { letter: "<script>", view: "az" }

    assert_response :success
    assert_select "a.places-list__link", count: 5
  end

  test "an unknown way in is not found" do
    get "/browse/nonsense"

    assert_response :not_found
  end

  test "with Solr down and nothing kept the page says so, instead of failing" do
    original = SolrGuard.method(:run)
    SolrGuard.define_singleton_method(:run) { |*| raise Errno::ECONNREFUSED }
    begin
      get "/browse/places"
    ensure
      SolrGuard.define_singleton_method(:run, original)
    end

    assert_response :service_unavailable
    assert_select "h1", "Places"
    assert_select ".unavailable-note", /cannot be shown right now\. Please try again in a few minutes/ # the one sentence
  end

  test "the home page's Explore groups link to their full lists" do
    Rails.cache.write(ExploreEntryPoints::CACHE_KEY, { "collections" => [ [ "University Art Collection", 1 ] ], "kinds" => [ [ "Paintings", 1, [ "paintings" ] ] ], "places" => [ [ "Japan", 1 ] ], "periods" => { ExploreEntryPoints.period_key(1900, 1999) => 1 } }, expires_in: 1.day)

    get "/"

    assert_select "section.explore-kinds a.home-section__link[href='/browse/classifications']"
    assert_select "section.home-places a.home-section__link[href='/browse/places']"
    assert_select "section.explore-periods a.home-section__link[href='/browse/time']"
  end

  # --- Entity pages (BrowseEntitiesController) and the filter box ---

  test "makers, places and subjects link to their entity pages, with spelling variants as one" do
    seed("subjects", [ [ "Portraits", 190 ], [ "portraits", 3 ], [ "Archaeology", 20 ] ])

    get "/browse/subjects", params: { view: "az" }

    assert_equal [ "Portraits", "Archaeology" ], css_select("a.places-list__link").map { |a| a.text.squish }
    assert_select "a.places-list__link[href='#{Browse.path_for('subjects', 'Portraits')}']"
  end

  test "the type-to-filter box is a plain GET form, narrows the list and says when nothing matches" do
    seed("places", [ [ "Australia", 20 ], [ "Austria", 5 ], [ "Japan", 9 ] ])

    get "/browse/places", params: { filter: "austr" }

    assert_select "form[method=get][action='/browse/places'] input[type=search][name=filter][value=austr]"
    assert_select "form label[for=filter]"
    assert_equal [ "Australia", "Austria" ], css_select("a.places-list__link").map { |a| a.text.squish } # Places has its own page
    get "/browse/places", params: { filter: "zzz" }
    assert_select ".browse-empty", /No place matches “zzz”/
  end

  test "a long list under a letter is paged" do
    seed("places", (1..130).map { |n| [ "Place #{format('%03d', n)}", n ] })

    get "/browse/places", params: { letter: "P" }
    assert_select "a.places-list__link", count: BrowseList::PAGE_SIZE
    assert_select "nav.browse-pager a[rel=next]"
    get "/browse/places", params: { letter: "P", page: 2 }
    assert_select "a.places-list__link", count: 10
  end
end
