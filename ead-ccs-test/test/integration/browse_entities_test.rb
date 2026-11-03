require "test_helper"
require_relative "../support/canned_search"
require_relative "../support/request_counter"
require_relative "../support/env_override"

# The browse entity pages (BrowseEntitiesController), answered by a canned Solr so they run in CI without a core. The real thing
# is checked against the shared index by hand and by the system test.
class BrowseEntitiesTest < ActionDispatch::IntegrationTest
  include CannedSearch
  include RequestCounter
  include EnvOverride

  MAKERS = { "Grainger, Percy Aldridge" => 5816, "Unknown" => 1400, "Bunny, Rupert" => 730, "Tiny, Tim" => 2 }.freeze
  PLACES = { "Australia" => 2321, "Melbourne, Victoria, Australia" => 1391, "Europe" => 4000, "Europe (?)" => 4 }.freeze
  SUBJECTS = { "Portraits" => 190, "portraits" => 3, "Archaeology" => 2482 }.freeze
  HUB_VALUES = { "makers" => MAKERS, "places" => PLACES, "subjects" => SUBJECTS }.freeze

  OPEN = { "id" => "emu-1", "title_tsim" => [ "Open portrait" ], "creator_ssim" => [ "Bunny, Rupert" ], "object_type_ssim" => [ "painting" ],
           "collection_ssim" => [ "University Art Collection" ], "thumbnail_path_ssi" => "/digital-assets/thumbs/open-one.jpg",
           "has_digital_asset_bsi" => true, "licence_type_ssim" => [ "Public domain - Copyright expired" ],
           "creator_display_ssim" => [ "Bunny, Rupert (29 September 1864 – 25-May-47) Artist" ], "date_start_isi" => 1890 }.freeze
  WITHHELD = { "id" => "emu-2", "title_tsim" => [ "Withheld secret title" ], "creator_ssim" => [ "Bunny, Rupert" ],
               "thumbnail_path_ssi" => "/digital-assets/thumbs/withheld-two.jpg", "licence_type_ssim" => [ "ICIP Rights" ] }.freeze
  SENSITIVE = { "id" => "emu-3", "title_tsim" => [ "Sensitive secret title" ], "creator_ssim" => [ "Bunny, Rupert" ],
                "thumbnail_path_ssi" => "/digital-assets/thumbs/sensitive-three.jpg", "licence_type_ssim" => [ "Public domain - Copyright expired" ],
                "restrictions_tsi" => [ "Culturally sensitive images. Only select images to be published online" ] }.freeze

  # Solr's answer to the entity page's one request: a page of records and the facts about them
  def answer(docs: [ OPEN ], total: 730, cultural: 0)
    lambda do |_params|
      canned_response(docs, total: total).merge(
        "stats" => { "stats_fields" => { "date_start_isi" => { "min" => 1816.0, "max" => 2019.0 } } },
        "facet_counts" => { "facet_fields" => { "collection_ssim" => { "University Art Collection" => 500 }, "object_type_ssim" => { "painting" => 400 },
                                                 "creator_ssim" => { "Bunny, Rupert" => 730, "Unknown" => 10, "Tiny, Tim" => 3 },
                                                 "production_place_ssim" => { "Australia" => 300 }, "subject_ssim" => { "Portraits" => 50 } },
                            "facet_queries" => { "cultural" => cultural },
                            "facet_ranges" => { "date_start_isi" => { "counts" => { "1800" => 600, "1900" => 130 }, "before" => 0 } } }
      )
    end
  end

  # The value lists are BrowseHubs' (its cache holds them for a day), so the entity pages need no request for them
  def seed_lists
    HUB_VALUES.each { |slug, values| Rails.cache.write("browse_hubs/v1/#{slug}", values.to_a, expires_in: 1.day) }
    Rails.cache.write("browse_hubs/v1/periods", [ [ "Before 1000", 15, -10_000, 999 ], [ "1900–1909", 130, 1900, 1909 ], [ "1890–1899", 600, 1890, 1899 ] ], expires_in: 1.day)
  end

  def browse(path, **options)
    with_seeded_menu_cache do
      seed_lists
      with_canned_search(answer(**options)) do |seen|
        @seen = seen
        get path
      end
    end
  end

  def entity_path(kind, value) = Browse.path_for(kind, value)

  # --- Entity pages ---

  test "a creator page has the name, facts, records, a link to the search, and related entities" do
    browse entity_path("makers", "Bunny, Rupert")

    assert_response :success
    assert_select "h1", "Bunny, Rupert"
    assert_select "title", /Bunny, Rupert — Maker/
    assert_select ".browse-facts dt", text: "Dates on records"
    assert_select ".browse-facts dd", text: "29 September 1864 – 25-May-47"
    assert_select ".browse-facts dd", text: "1816 to 2019"
    assert_select ".result-card", count: 1
    assert_select "a.btn[href*='f%5Bcreator_ssim%5D%5B%5D=Bunny%2C+Rupert']", text: /See all 730 records/
    assert_select ".browse-related a", text: "Australia"
    assert_select ".browse-related a", text: "Tiny, Tim"
    assert_select ".browse-related a", text: "Unknown", count: 0
    assert_select ".browse-related a[href='/browse/periods/1900-1999']"
  end

  test "an entity with a stale slug goes to its address, and an unknown or malformed one is a 404" do
    path = entity_path("places", "Australia")
    browse path.sub("australia-", "oz-")

    assert_redirected_to path
    assert_response :moved_permanently
    browse "/browse/places/australia-0000000000"
    assert_response :not_found
    browse "/browse/places/nothing"
    assert_response :not_found
  end

  test "a variant spelling leads to the entity's page, which names the commonest spelling" do
    browse entity_path("places", "Europe (?)")

    assert_response :success
    assert_select "h1", "Europe"
  end

  test "an entity page searches the records of every variant of the entity" do
    browse entity_path("subjects", "Portraits")
    assert_select "a.btn[href*='f_inclusive']", text: /See all 730 records/
    assert_equal [ %(subject_ssim:("Portraits" OR "portraits")) ], @seen.find { |params| params[:fq] }[:fq]
  end

  test "the records of a period page are those in its years, and the page lists its decades" do
    browse "/browse/periods/1900-1999"

    assert_response :success
    assert_select "h1", "1900–1999"
    assert_equal [ "date_start_isi:[1900 TO 1999]" ], @seen.find { |params| params[:fq] }[:fq]
    assert_select "a.btn[href*='range%5Bdate_start_isi%5D%5Bbegin%5D=1900']"
    assert_select "#related-periods", text: "Within this period"
    browse "/browse/periods/1900-1950"
    assert_response :not_found
  end

  # --- Withheld and sensitive records ---

  test "a withheld or sensitive record is not drawn: no title, no image path, and the page says some are held back" do
    browse entity_path("makers", "Bunny, Rupert"), docs: [ OPEN, WITHHELD, SENSITIVE ], total: 3

    assert_response :success
    assert_select ".result-card", count: 1
    assert_includes response.body, "open-one.jpg"
    %w[withheld-two sensitive-three Withheld\ secret Sensitive\ secret].each { |leak| assert_not_includes response.body, leak }
    assert_select ".browse-note", /not previewed/
  end

  test "the structured data names the page and carries no image or record title" do
    browse entity_path("makers", "Bunny, Rupert"), docs: [ OPEN, WITHHELD ]

    data = JSON.parse(css_select("script[type='application/ld+json']").first.text)
    assert_equal "CollectionPage", data["@type"]
    assert_equal "Person", data["about"]["@type"]
    assert_equal "Bunny, Rupert", data["about"]["name"]
    assert_equal %w[Browse Makers Bunny,\ Rupert], data["breadcrumb"]["itemListElement"].pluck("name")
    assert_not_includes response.body[/<script type="application\/ld\+json">.*?<\/script>/m].to_s, "jpg"
  end

  test "an organisation is not called a person" do
    browse entity_path("makers", "Bunny, Rupert"), docs: [ OPEN.merge("creator_display_ssim" => [ "Bunny, Rupert Ltd (estab. 1900) Maker" ]) ]

    data = JSON.parse(css_select("script[type='application/ld+json']").first.text)
    assert_equal "Thing", data["about"]["@type"]
  end

  test "records under cultural protocols bring the cultural care notice" do
    browse entity_path("makers", "Bunny, Rupert"), cultural: 2
    assert_select ".browse-advisory a[href='/help#indigenous']"

    browse entity_path("makers", "Bunny, Rupert"), cultural: 0
    assert_select ".browse-advisory", count: 0
  end

  # --- Search engines ---

  test "a page with five records or more is indexable, canonical, and described; a thin page asks not to be indexed" do
    with_env_indexing do
      browse entity_path("makers", "Bunny, Rupert")
      assert_select "link[rel=canonical][href$=?]", entity_path("makers", "Bunny, Rupert")
      assert_select "meta[name=description][content*='730 records']"
      assert_select "meta[name=robots]", count: 1 do |tag|
        assert_no_match(/noindex/, tag.first["content"])
      end
      assert_no_match(/noindex/, response.headers["X-Robots-Tag"].to_s)

      browse entity_path("makers", "Tiny, Tim"), total: 2
      assert_select "meta[name=robots][content*='noindex, follow']"
      assert_match(/noindex, follow/, response.headers["X-Robots-Tag"])
    end
  end

  test "the sitemap lists the index pages and the pages worth indexing, not the thin ones" do
    paths = with_seeded_menu_cache do
      seed_lists
      Browse::SitemapPaths.paths
    end

    assert_includes paths, "/browse"
    assert_includes paths, "/browse/periods"
    assert_includes paths, entity_path("makers", "Bunny, Rupert")
    assert_includes paths, "/browse/periods/1900-1909"
    assert_includes paths, "/browse/periods/1900-1999" # the century of a listed decade
    assert_not_includes paths, entity_path("makers", "Tiny, Tim")
    assert_equal paths.uniq, paths
  end

  # --- Budgets ---

  test "with the value lists cached an entity page makes one Solr request" do
    with_seeded_menu_cache do
      seed_lists
      with_canned_search(answer) do |seen|
        get entity_path("makers", "Bunny, Rupert")
        assert_equal 1, seen.size
        seen.clear
        get "/browse/periods/1900-1999"
        assert_equal 1, seen.size
      end
    end
  end

  test "an unlisted value, with Solr down and nothing kept, is said plainly" do
    original = SolrGuard.method(:run)
    SolrGuard.define_singleton_method(:run) { |*| raise Errno::ECONNREFUSED }
    begin
      with_seeded_menu_cache { get Browse.path_for("makers", "Bunny, Rupert") }
    ensure
      SolrGuard.define_singleton_method(:run, original)
    end

    assert_response :service_unavailable
    assert_select "h1", "Browse"
  end

  private

  def with_env_indexing(&block)
    with_env({ "SEO_INDEXING" => "on" }, &block)
  end
end
