# frozen_string_literal: true

require "test_helper"

class ExploreComponentTest < ViewComponent::TestCase
  IMAGE = ExploreEntryPoints::Image.new(id: "emu-9", title: "A bronze lyre", path: "/digital-assets/thumbs/0000_013_1_pf.jpg", width: 400, height: 300)

  def tile(label, count, tint, image: nil) = ExploreEntryPoints::Tile.new(label: label, count: count, query: BrowseHubs.query("collection_ssim", label), image: image, tint: tint)

  def overview(image: nil, indigenous_image: nil)
    kinds = [ ExploreEntryPoints::Link.new("Paintings", 2555, Browse.search_query("classification_ssim", [ "paintings" ])),
              ExploreEntryPoints::Link.new("Prints and drawings", 7192, Browse.search_query("classification_ssim", %w[prints drawings])) ]
    places = [ ExploreEntryPoints::Link.new("Australia", 8056, BrowseHubs.query("production_place_ssim", "Australia")) ]
    periods = [ ExploreEntryPoints::Link.new("1900s", 5000, BrowseHubs.period_query(1900, 1999)) ]
    ExploreEntryPoints::Overview.new(
      [ tile("University Art Collection", 14_537, 1, image: image), tile("Indigenous Collections", 1540, 2, image: indigenous_image), tile("Medical History Museum", 1, 3) ],
      kinds, places, periods,
      ExploreEntryPoints.send(:link_tiles, kinds, {}), ExploreEntryPoints.send(:link_tiles, places, {}), ExploreEntryPoints.send(:link_tiles, periods, {})
    )
  end

  def empty_overview(collections = []) = ExploreEntryPoints::Overview.new(collections, [], [], [], [], [], [])

  test "the home sections in order, each heading on the left with its See all link: the museums, visiting them, record types, places and time" do
    render_inline NexusCcs::ExploreComponent.new(overview: overview)

    headings = page.all("section.home-section h2").map(&:text)
    assert_equal [ "Explore the collections", "Visit the collections", "Record types", "Places", "Time" ], headings # no named collections without the index
    assert_selector "section.explore .home-section__head a.home-section__link[href='/browse/categories/collections']", text: "See all collections"
    assert_selector "section.explore-kinds a.home-section__link[href='/browse/object-types']", text: "See all object types"
    assert_selector "section.home-places a.home-section__link[href='/browse/places']", text: "See all places"
    assert_selector "section.explore-periods a.home-section__link[href='/browse/periods']", text: "See all periods"
  end

  test "Explore the collections: the five museums in justified rows, the University Art Collection first as the lead with its blurb and a call to action" do
    render_inline NexusCcs::ExploreComponent.new(overview: overview)

    tiles = page.all("section.explore ul.justified[data-controller=justified] > li.justified__item")
    assert_equal 5, tiles.size
    assert_equal "University Art Collection", tiles.first.find("h3").text
    assert tiles.first[:class].include?("justified__item--lead")
    assert tiles.all? { |tile| tile[:style].to_s.match?(/--a: \d/) } # each banner's shape, from its size
    assert_selector "section.explore li.justified__item--lead article.result-card.explore-card--lead .explore-card__cta", text: "Explore the collection"
    assert_selector "section.explore article.result-card.explore-card--tile h3.document-title-heading a[href='/browse/collections/#{Browse::Slug.build('collections', 'Grainger Museum Collection')}']", text: "Grainger Museum Collection"
    assert_selector "section.explore a.result-card__media[tabindex='-1'][aria-hidden=true] img[alt=''][loading=lazy]", count: 5 # the name is the link text
    assert_no_selector "section.explore, section.home-named", text: /\d records/ # no record counts on collections
  end

  test "Visit the collections: Grainger leads (first, on the left) with its hours and access, every tile opening the museum's own visitor page" do
    render_inline NexusCcs::ExploreComponent.new(overview: overview)

    lead = page.find("section.home-visit ul.justified > li:first-child")
    assert lead[:class].include?("justified__item--lead")
    assert_equal "https://grainger.unimelb.edu.au/visit", lead.find("h3 a")[:href]
    assert_includes lead.text, "Open Monday, 1-4pm. Grainger Museum is step-free"
    assert_selector "section.home-visit article.explore-card--tile", count: 5
    assert_selector "section.home-visit h3 .visually-hidden", text: "(the museum's website)", count: 5
  end

  test "Record types are a shelf, Places a list beside a preview, Time justified rows; a type with several values is an any-of filter" do
    render_inline NexusCcs::ExploreComponent.new(overview: overview)

    assert_selector "section.explore-kinds .card-layout--shelf[data-controller=card-rail] li.card-layout__item article.result-card", count: 2
    assert_selector "article.result-card h3 a[href*='f_inclusive%5Bclassification_ssim%5D%5B%5D=prints'][href*='f_inclusive%5Bclassification_ssim%5D%5B%5D=drawings']", text: "Prints and drawings"
    assert_selector "section.home-places .place-preview ul[aria-label=Places] a.place-row[aria-current=true][href*='f%5Bproduction_place_ssim%5D%5B%5D=Australia']", text: "Australia"
    assert_selector "section.home-places .place-preview__panels[aria-hidden=true]"
    assert_selector "section.explore-periods .card-layout--justified ul.justified[data-controller=justified] li.justified__item article.result-card h3 a[href*='range%5Bdate_start_isi%5D%5Bbegin%5D=1900']", text: "1900s"
  end

  test "with no record types, places or times, those sections are left out without leaving a heading behind" do
    render_inline NexusCcs::ExploreComponent.new(overview: empty_overview([ tile("University Art Collection", 1, 1) ]))

    assert_selector "section.explore h2", text: "Explore the collections"
    assert_no_selector "section.explore-kinds, section.home-places, section.explore-periods"
  end
end
