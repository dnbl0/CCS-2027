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
  def seed_cards(slug, entries) = Rails.cache.write(SuppressedRecord.cache_key("browse_cards/v3/#{slug}"), entries, expires_in: 1.day)

  def entry(label, **extra) = { "label" => label, "count" => 5, "intro" => "Includes prints. Held in University Art Collection.", "image" => nil }.merge(extra.transform_keys(&:to_s))

  test "the browse page is one section for each way in, with its heading and a link to every value" do
    get "/browse"

    assert_response :success
    assert_select "h1", "Browse the collections"
    assert_select "main > section.ccs-section", count: BrowseHubs.all.size
    BrowseHubs.all.each do |hub|
      assert_select "section.browse-#{hub.slug}[aria-labelledby='browse-#{hub.slug}'] h2#browse-#{hub.slug}", hub.title
      assert_select "section.browse-#{hub.slug} a.explore__all[href='/browse/#{hub.slug}']"
    end
  end

  test "each section shows its cards, each with its description and opening the results with its filter applied" do
    image = { id: "r1", title: "A print", path: "https://dam.example.org/a.jpg", width: nil, height: nil }
    seed_cards("object-types", [ entry("Medical device", "image" => image) ] + (1..7).map { |number| entry("Type #{number}") })

    get "/browse"

    assert_select "section.browse-object-types article.explore-card", count: 8
    assert_select "section.browse-object-types h3.document-title-heading a[href*='f%5Bclassification_ssim%5D%5B%5D=Medical+device'][href*='any_assets=1']", text: "Medical device"
    assert_select "section.browse-object-types .explore-card__intro", text: "Includes prints. Held in University Art Collection.", count: 8
    assert_select "section.browse-object-types article.explore-card img[src*='dam.example.org']", count: 1
    assert_select "section.browse-object-types article.explore-card svg", count: 0 # no arrow
    assert_select "section.browse-object-types .explore-card__intro", text: /records/, count: 0 # a description, not a count
  end

  test "the periods section opens the results with that period's range" do
    seed_cards("periods", [ entry("1950–1959", "first" => 1950, "last" => 1959) ])

    get "/browse"

    assert_select "section.browse-periods h3 a[href*='range%5Bdate_start_isi%5D%5Bbegin%5D=1950'][href*='range%5Bdate_start_isi%5D%5Bend%5D=1959']", text: "1950–1959"
  end

  test "a section whose list is unavailable keeps its heading and link but has no cards" do
    with_solr_down { get "/browse" }

    assert_response :success
    assert_select "section.browse-makers h2", "Makers"
    assert_select "section.browse-makers article", count: 0
  end

  test "a way in lists the most common values first, each opening all its records with its count" do
    seed("object-types", VALUES)

    get "/browse/object-types"

    assert_response :success
    assert_select "h1", "Browse object types"
    links = css_select("a.browse__link").map { |a| a.text.squish }
    assert_equal [ "Lyre 120 records", "Harp 40 records", "Bell 3 records", "Étui 1 record", "1973 print 1 record" ], links
    assert_select "a.browse__link[href*='f%5Bobject_type_ssim%5D%5B%5D=lyre'][href*='any_assets=1']"
  end

  test "a letter shows the values that start with it, alphabetically, and says which letter it is" do
    seed("object-types", VALUES)

    get "/browse/object-types", params: { letter: "B" }

    assert_select "a.browse__link", count: 1
    assert_select "a.browse__link", text: /Bell/
    assert_select "nav[aria-label='Browse by letter'] a[aria-current='page']", text: "B"
    assert_select "nav[aria-label='Browse by letter'] a", text: "Z", count: 0 # only letters that have records
  end

  test "a letter that does not exist is the default list, not an error" do
    seed("object-types", VALUES)

    get "/browse/object-types", params: { letter: "<script>" }

    assert_response :success
    assert_select "a.browse__link", count: 5
  end

  test "the periods page lists the periods in order, from Before 1000 to now" do
    Rails.cache.write("browse_hubs/v1/periods", [ [ "Before 1000", 2, -10_000, 999 ], [ "1950–1959", 12, 1950, 1959 ] ], expires_in: 1.day)

    get "/browse/periods"

    assert_response :success
    assert_equal [ "Before 1000 2 records", "1950–1959 12 records" ], css_select("a.browse__link").map { |a| a.text.squish }
    assert_select "a.browse__link[href='/browse/periods/1950-1959']" # each period has a page of its own, which links to the search
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
    assert_select "h1", "Browse places"
    assert_select ".browse__unavailable"
  end

  test "the home page's Explore groups link to their full lists" do
    Rails.cache.write(ExploreEntryPoints::CACHE_KEY, { "collections" => [ [ "University Art Collection", 1 ] ], "kinds" => [ [ "Paintings", 1, [ "paintings" ] ] ], "places" => [ [ "Japan", 1 ] ], "periods" => { ExploreEntryPoints.period_key(1900, 1999) => 1 } }, expires_in: 1.day)

    get "/"

    assert_select "section.explore-kinds a.explore__all[href='/browse/object-types']"
    assert_select "section.explore-places a.explore__all[href='/browse/places']"
    assert_select "section.explore-periods a.explore__all[href='/browse/periods']"
  end

  # --- Entity pages (BrowseEntitiesController) and the filter box ---

  test "makers, places and subjects link to their entity pages, with spelling variants as one" do
    seed("subjects", [ [ "Portraits", 190 ], [ "portraits", 3 ], [ "Archaeology", 20 ] ])

    get "/browse/subjects"

    assert_equal [ "Portraits 193 records", "Archaeology 20 records" ], css_select("a.browse__link").map { |a| a.text.squish }
    assert_select "a.browse__link[href='#{Browse.path_for('subjects', 'Portraits')}']"
  end

  test "periods link to their pages" do
    Rails.cache.write("browse_hubs/v1/periods", [ [ "Before 1000", 2, -10_000, 999 ], [ "1950–1959", 12, 1950, 1959 ] ], expires_in: 1.day)

    get "/browse/periods"

    assert_select "a.browse__link[href='/browse/periods/before-1000']"
    assert_select "a.browse__link[href='/browse/periods/1950-1959']"
  end

  test "the type-to-filter box is a plain GET form, narrows the list and says when nothing matches" do
    seed("places", [ [ "Australia", 20 ], [ "Austria", 5 ], [ "Japan", 9 ] ])

    get "/browse/places", params: { filter: "austr" }

    assert_select "form[method=get][action='/browse/places'] input[type=search][name=filter][value=austr]"
    assert_select "form label[for=filter]"
    assert_equal [ "Australia 20 records", "Austria 5 records" ], css_select("a.browse__link").map { |a| a.text.squish }
    get "/browse/places", params: { filter: "zzz" }
    assert_select ".browse-empty", /Nothing matches/
  end

  test "a long list under a letter is paged" do
    seed("places", (1..130).map { |n| [ "Place #{format('%03d', n)}", n ] })

    get "/browse/places", params: { letter: "P" }
    assert_select "a.browse__link", count: BrowseList::PAGE_SIZE
    assert_select "nav.browse-pager a[rel=next]"
    get "/browse/places", params: { letter: "P", page: 2 }
    assert_select "a.browse__link", count: 10
  end
end
