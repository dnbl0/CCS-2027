require "test_helper"
require_relative "../support/canned_search"
require_relative "../support/request_counter"
require_relative "../support/env_override"

# The browse hubs and entity pages (BrowseController), answered by a canned Solr so they run in CI without a core. The real thing
# is checked against the shared index by hand and by the system test.
class BrowseTest < ActionDispatch::IntegrationTest
  include CannedSearch
  include RequestCounter
  include EnvOverride

  CREATORS = { "Grainger, Percy Aldridge" => 5816, "Unknown" => 1400, "Bunny, Rupert" => 730, "Tiny, Tim" => 2 }.freeze
  PLACES = { "Australia" => 2321, "Melbourne, Victoria, Australia" => 1391, "Europe" => 4000, "Europe (?)" => 4 }.freeze
  SUBJECTS = { "Portraits" => 190, "portraits" => 3, "Archaeology" => 2482 }.freeze
  FIELDS = { "creator_ssim" => CREATORS, "production_place_ssim" => PLACES, "subject_ssim" => SUBJECTS }.freeze

  OPEN = { "id" => "emu-1", "title_tsim" => [ "Open portrait" ], "creator_ssim" => [ "Bunny, Rupert" ], "object_type_ssim" => [ "painting" ],
           "collection_ssim" => [ "University Art Collection" ], "thumbnail_path_ssi" => "/digital-assets/thumbs/open-one.jpg",
           "has_digital_asset_bsi" => true, "licence_type_ssim" => [ "Public domain - Copyright expired" ],
           "creator_display_ssim" => [ "Bunny, Rupert (29 September 1864 – 25-May-47) Artist" ], "date_start_isi" => 1890 }.freeze
  WITHHELD = { "id" => "emu-2", "title_tsim" => [ "Withheld secret title" ], "creator_ssim" => [ "Bunny, Rupert" ],
               "thumbnail_path_ssi" => "/digital-assets/thumbs/withheld-two.jpg", "licence_type_ssim" => [ "ICIP Rights" ] }.freeze
  SENSITIVE = { "id" => "emu-3", "title_tsim" => [ "Sensitive secret title" ], "creator_ssim" => [ "Bunny, Rupert" ],
                "thumbnail_path_ssi" => "/digital-assets/thumbs/sensitive-three.jpg", "licence_type_ssim" => [ "Public domain - Copyright expired" ],
                "restrictions_tsi" => [ "Culturally sensitive images. Only select images to be published online" ] }.freeze

  # Solr's answers by request: a facet of one field (the value lists), the periods, or a page of records
  def answer(docs: [ OPEN ], total: 730, cultural: 0)
    lambda do |params|
      field = params[:"facet.field"]
      if params[:rows].to_i.zero? && FIELDS.key?(field)
        canned_response([]).merge("facet_counts" => { "facet_fields" => { field => FIELDS[field] }, "facet_ranges" => {}, "facet_queries" => {} })
      elsif params[:rows].to_i.zero?
        centuries = params[:"facet.range.gap"] == 100
        counts = centuries ? { "1800" => 4038, "1900" => 20_146, "-500" => 101, "0" => 48 } : { "1890" => 120, "1920" => 800 }
        canned_response([]).merge("facet_counts" => { "facet_fields" => {}, "facet_queries" => {},
                                                       "facet_ranges" => { "date_start_isi" => { "counts" => counts, "before" => centuries ? 15 : 0 } } })
      else
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
  end

  def browse(path, **options)
    with_seeded_menu_cache do
      with_canned_search(answer(**options)) do |seen|
        @seen = seen
        get path
      end
    end
  end

  def entity_path(kind, value) = Browse.path_for(kind, value)

  # --- Hubs ---

  test "the overview links the four hubs with their commonest values" do
    browse "/browse"

    assert_response :success
    assert_select "h1", "Browse"
    %w[creators places subjects time].each { |hub| assert_select "main a[href=?]", "/browse/#{hub}" }
    assert_select "main a", text: "Grainger, Percy Aldridge"
    assert_select "main a", text: "Unknown", count: 0
  end

  test "a hub is an A to Z list with record counts; noise is left out and variants are one entity" do
    browse "/browse/subjects"

    assert_select "title", /Subjects — Browse/
    assert_select ".browse-list__link", count: 2
    assert_select "main li", text: /Portraits\s+193 records/
    browse "/browse/creators"
    assert_select "main a", text: "Unknown", count: 0
    assert_select "main a", text: "Tiny, Tim"
  end

  test "the type-to-filter box is a plain GET form that works without JavaScript" do
    browse "/browse/creators?filter=bunny"

    assert_select "form[method=get][action='/browse/creators'] input[type=search][name=filter][value=bunny]"
    assert_select "form label[for=filter]"
    assert_select ".browse-list__link", count: 1
    assert_select ".browse-list__link", text: "Bunny, Rupert"
    assert_select "meta[name=robots][content*=noindex]"
  end

  test "a filter with no match says so" do
    browse "/browse/creators?filter=zzzz"

    assert_select ".browse-empty", /Nothing matches/
  end

  test "the letter bar offers letters that have values, marks the current one, and filters" do
    browse "/browse/creators?letter=G"

    assert_select ".browse-letters a[aria-current=true]", text: "G"
    assert_select ".browse-letters a", text: "B"
    assert_select ".browse-letters a", text: "Z", count: 0
    assert_select ".browse-list__link", count: 1
    assert_select "title", /starting with G/
  end

  test "an unknown hub is a 404" do
    browse "/browse/colours"

    assert_response :not_found
  end

  test "the time hub lists centuries and decades with counts" do
    browse "/browse/time"

    assert_response :success
    assert_select "a[href='/browse/time/1900-1999']", text: "1900s"
    assert_select "a[href='/browse/time/bce-500-401']", text: "500–401 BCE"
    assert_select "a[href='/browse/time/before-5000-bce']"
    assert_select "a[href='/browse/time/1920-1929']", text: "1920s"
  end

  # --- Entity pages ---

  test "a creator page has the name, facts, records, a link to the search, and related entities" do
    browse entity_path("creators", "Bunny, Rupert")

    assert_response :success
    assert_select "h1", "Bunny, Rupert"
    assert_select "title", /Bunny, Rupert — Creator/
    assert_select ".browse-facts dt", text: "Dates on records"
    assert_select ".browse-facts dd", text: "29 September 1864 – 25-May-47"
    assert_select ".browse-facts dd", text: "1816 to 2019"
    assert_select ".result-card", count: 1
    assert_select "a.btn[href*='f%5Bcreator_ssim%5D%5B%5D=Bunny%2C+Rupert']", text: /See all 730 records/
    assert_select ".browse-related a", text: "Australia"
    assert_select ".browse-related a", text: "Tiny, Tim"
    assert_select ".browse-related a", text: "Unknown", count: 0
    assert_select ".browse-related a[href='/browse/time/1900-1999']"
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
    browse "/browse/time/1900-1999"

    assert_response :success
    assert_select "h1", "1900s"
    assert_equal [ "date_start_isi:[1900 TO 1999]" ], @seen.find { |params| params[:fq] }[:fq]
    assert_select "a.btn[href*='range%5Bdate_start_isi%5D%5Bbegin%5D=1900']"
    assert_select "#related-periods", text: "Within this period"
    browse "/browse/time/1900-1950"
    assert_response :not_found
  end

  # --- Withheld and sensitive records ---

  test "a withheld or sensitive record is not drawn: no title, no image path, and the page says some are held back" do
    browse entity_path("creators", "Bunny, Rupert"), docs: [ OPEN, WITHHELD, SENSITIVE ], total: 3

    assert_response :success
    assert_select ".result-card", count: 1
    assert_includes response.body, "open-one.jpg"
    %w[withheld-two sensitive-three Withheld\ secret Sensitive\ secret].each { |leak| assert_not_includes response.body, leak }
    assert_select ".browse-note", /not previewed/
  end

  test "the structured data names the page and carries no image or record title" do
    browse entity_path("creators", "Bunny, Rupert"), docs: [ OPEN, WITHHELD ]

    data = JSON.parse(css_select("script[type='application/ld+json']").first.text)
    assert_equal "CollectionPage", data["@type"]
    assert_equal "Person", data["about"]["@type"]
    assert_equal "Bunny, Rupert", data["about"]["name"]
    assert_equal %w[Browse Creators Bunny,\ Rupert], data["breadcrumb"]["itemListElement"].pluck("name")
    assert_not_includes response.body[/<script type="application\/ld\+json">.*?<\/script>/m].to_s, "jpg"
  end

  test "an organisation is not called a person" do
    browse entity_path("creators", "Bunny, Rupert"), docs: [ OPEN.merge("creator_display_ssim" => [ "Bunny, Rupert Ltd (estab. 1900) Maker" ]) ]

    data = JSON.parse(css_select("script[type='application/ld+json']").first.text)
    assert_equal "Thing", data["about"]["@type"]
  end

  test "records under cultural protocols bring the cultural care notice" do
    browse entity_path("creators", "Bunny, Rupert"), cultural: 2
    assert_select ".browse-advisory a[href='/help#indigenous']"

    browse entity_path("creators", "Bunny, Rupert"), cultural: 0
    assert_select ".browse-advisory", count: 0
  end

  # --- Search engines ---

  test "a page with five records or more is indexable, canonical, and described; a thin page asks not to be indexed" do
    with_env_indexing do
      browse entity_path("creators", "Bunny, Rupert")
      assert_select "link[rel=canonical][href$=?]", entity_path("creators", "Bunny, Rupert")
      assert_select "meta[name=description][content*='730 records']"
      assert_select "meta[name=robots]", count: 1 do |tag|
        assert_no_match(/noindex/, tag.first["content"])
      end
      assert_no_match(/noindex/, response.headers["X-Robots-Tag"].to_s)

      browse entity_path("creators", "Tiny, Tim"), total: 2
      assert_select "meta[name=robots][content*='noindex, follow']"
      assert_match(/noindex, follow/, response.headers["X-Robots-Tag"])
    end
  end

  test "the sitemap lists the hubs and the pages worth indexing, not the thin ones" do
    paths = with_seeded_menu_cache { with_canned_search(answer) { Browse::SitemapPaths.paths } }

    assert_includes paths, "/browse"
    assert_includes paths, "/browse/time"
    assert_includes paths, entity_path("creators", "Bunny, Rupert")
    assert_includes paths, "/browse/time/1900-1999"
    assert_not_includes paths, entity_path("creators", "Tiny, Tim")
    assert_equal paths.uniq, paths
  end

  # --- Budgets ---

  test "once the value lists are cached, a hub makes no Solr request and an entity page makes one" do
    with_seeded_menu_cache do
      with_canned_search(answer) do |seen|
        get "/browse/creators"
        get "/browse"
        cold = seen.size
        seen.clear
        get "/browse/creators"
        assert_equal 0, seen.size, "a hub with cached lists asks Solr"
        get entity_path("creators", "Bunny, Rupert")
        assert_equal 1, seen.size, "an entity page asks Solr more than once"
        assert_operator cold, :<=, 5
      end
    end
  end

  test "a Solr outage is said plainly, not a stack trace" do
    with_seeded_menu_cache do
      with_canned_search(->(_params) { raise Blacklight::Exceptions::ECONNREFUSED }) { get "/browse/creators" }
    end

    assert_response :service_unavailable
  end

  private

  def with_env_indexing(&block)
    with_env({ "SEO_INDEXING" => "on" }, &block)
  end
end
