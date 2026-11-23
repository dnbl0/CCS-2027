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

  test "the home sections in order, each heading on the left with its See all link; no Visit section" do
    render_inline NexusCcs::ExploreComponent.new(overview: overview)

    headings = page.all("section.home-section h2").map(&:text)
    assert_equal [ "Explore the collections", "Record types", "Places", "Time" ], headings # no named collections without the index
    assert_selector "section.explore .home-section__head a.home-section__link[href='/browse/categories/collections']", text: "See all collections"
    assert_selector "section.explore-kinds a.home-section__link[href='/browse/object-types']", text: "See all object types"
    assert_selector "section.home-places a.home-section__link[href='/browse/places']", text: "See all places"
    assert_selector "section.explore-periods a.home-section__link[href='/browse/periods']", text: "See all periods"
    assert_no_selector "section.home-visit"
  end

  test "Explore the collections: every collection as a fluid mosaic, the University Art Collection first as the lead; Indigenous Collections has no picture" do
    render_inline NexusCcs::ExploreComponent.new(overview: overview(image: IMAGE, indigenous_image: IMAGE))

    tiles = page.all("section.explore ul.mosaic-flow[data-controller=mosaic] > li.mosaic-flow__item")
    assert_equal [ "University Art Collection", "Indigenous Collections", "Medical History Museum" ], tiles.map { |tile| tile.find("h3").text }
    assert tiles.first[:class].include?("mosaic-flow__item--lead")
    assert_equal "--a: 1.333", tiles.first[:style] # its picture's shape, from its size
    assert_selector "section.explore li.mosaic-flow__item--lead .explore-card__cta", text: "Explore the collection"
    assert_selector "section.explore h3 a[href*='f%5Bcollection_ssim%5D%5B%5D=University+Art+Collection']", text: "University Art Collection"
    assert_no_selector "section.explore li:nth-child(2) img" # Indigenous Collections is kept text only
    assert_no_selector "section.explore, section.home-named", text: /\d records/ # no record counts on collections
  end

  test "Record types are a shelf of collage cards, one per kind; Places a list beside a collage; Time justified rows" do
    render_inline NexusCcs::ExploreComponent.new(overview: overview)

    assert_selector "section.explore-kinds .card-layout--collage[data-controller=card-rail] li.card-layout__item article.explore-card--collage", count: 2
    assert_selector "article.explore-card--collage h3 a[href*='f_inclusive%5Bclassification_ssim%5D%5B%5D=prints'][href*='f_inclusive%5Bclassification_ssim%5D%5B%5D=drawings']", text: "Prints and drawings"
    assert_selector "article.explore-card--collage .explore-card__intro", text: "7,192 records"
    assert_selector "section.home-places .place-preview ul[aria-label=Places] a.place-row[aria-current=true][href*='f%5Bproduction_place_ssim%5D%5B%5D=Australia']", text: "Australia"
    assert_selector "section.home-places .place-preview__panels[aria-hidden=true] .place-collage"
    assert_selector "section.explore-periods .card-layout--justified ul.justified[data-controller=justified] li.justified__item article.result-card h3 a[href*='range%5Bdate_start_isi%5D%5Bbegin%5D=1900']", text: "1900s"
  end

  test "with no record types, places or times, those sections are left out without leaving a heading behind" do
    render_inline NexusCcs::ExploreComponent.new(overview: empty_overview([ tile("University Art Collection", 1, 1) ]))

    assert_selector "section.explore h2", text: "Explore the collections"
    assert_no_selector "section.explore-kinds, section.home-places, section.explore-periods"
  end
end
