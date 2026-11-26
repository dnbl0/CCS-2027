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
    assert_equal [ "Explore the collections", "Classifications", "Places", "Time" ], headings
    assert_selector "section.explore .home-section__head a.home-section__link[href='/browse/collections']", text: "See all collections"
    assert_selector "section.explore-kinds a.home-section__link[href='/browse/classifications']", text: "See all classifications"
    assert_selector "section.home-places a.home-section__link[href='/browse/places']", text: "See all places"
    assert_selector "section.explore-periods a.home-section__link[href='/browse/time']", text: "See all periods"
    assert_no_selector "section.home-visit"
  end

  test "Explore the collections and the University of Melbourne Art Collection: the University's simple listing, its titles and pictures" do
    render_inline NexusCcs::ExploreComponent.new(overview: overview(image: IMAGE, indigenous_image: IMAGE))

    museums = page.all("section.explore ul.simple-listing.simple-listing--four > li.simple-listing__item")
    assert_equal HomeCollections.museums.size + HomeCollections.art_collection.size, museums.size # the Art Collection's are in the section too
    assert_equal "Architecture, Building and Planning Library Rare Material Collection", museums.first.find("h3").text
    assert_selector "section.explore li.simple-listing__item:first-child img.simple-listing__img[alt=''][src*='museumsandcollections.unimelb.edu.au']"
    # no index here, so no collection page: the collection's page on the University's sites, said under its title
    assert_selector "section.explore h3 a.simple-listing__link[href='https://medicalhistorymuseum.mdhs.unimelb.edu.au/home'][aria-describedby]", text: "Medical History Museum"
    assert_selector "section.explore li.simple-listing__item p.simple-listing__away", text: "On the University's website", minimum: 1
    assert_selector "section.explore .home-art-collection h3#home-art-collection-heading", text: "University of Melbourne Art Collection"
    art = page.all("section.explore .home-art-collection ul.simple-listing > li h4").map(&:text)
    assert_equal HomeCollections.art_collection.map(&:title), art
    assert_includes art, "Gerard Herbst Poster Collection"
    assert_no_selector ".explore-card__cta" # no call to action on any card
  end

  test "Classifications (on a band of colour) and Places as fanned stacks of cards; Time as the National Gallery of Art's card carousel" do
    render_inline NexusCcs::ExploreComponent.new(overview: overview)

    assert_selector "section.explore-kinds.home-section--tinted[style*='--section-background-color'] h2", text: "Classifications"
    assert_selector "section.explore-kinds ul.stack[data-controller=stack] li.stack__item article.stack__card", count: 2
    assert_selector "section.explore-kinds li.stack__item.is-centre[data-away='0']", text: "Paintings" # the middle card starts at the centre
    assert_selector "section.explore-kinds li.stack__item[data-away='1']", text: "Prints and drawings"
    assert_selector "section.explore-kinds .stack__card h3 a.stack__link[href*='f_inclusive%5Bclassification_ssim%5D%5B%5D=prints'][href*='f_inclusive%5Bclassification_ssim%5D%5B%5D=drawings']", text: "Prints and drawings"
    # a line on what the page holds where the number of records was (none here: the test has no index to describe them from)
    assert_no_selector "section.explore-kinds, section.home-places, section.explore-periods", text: /\d records/
    assert_selector "section.home-places ul.stack:not(.stack--bare) .stack__card h3 a.stack__link", text: "Australia" # its own page, or its records where it has none
    # Time: a slide for each period, in time order, named "1 of 2"; the buttons move it, the first starts marked disabled
    carousel = "section.explore-periods [role=region][aria-roledescription=carousel][data-controller=carousel]"
    assert_selector "#{carousel}.card-carousel div.card-carousel__slide[role=group][aria-roledescription=slide][aria-label='1 of #{overview.period_tiles.size}']"
    assert_selector "#{carousel} .card-carousel__card h3 a.card-carousel__link[href='/browse/periods/1900-1999']", text: "1900s" # its own page
    assert_selector "#{carousel} .card-carousel__card .card-carousel__meta", text: "1900–1999" # its years, the card's bold line
    assert_selector "#{carousel} .card-carousel__status[aria-live=polite]", text: "1 of #{overview.period_tiles.size}"
    assert_selector "#{carousel} button[aria-label='Previous period'][aria-disabled=true]"
    assert_selector "#{carousel} button[aria-label='Next period']"
    assert_no_selector ".explore-card--collage, .place-spot" # the shelf of collages and the place tabs are gone
  end

  test "today's Look closer picture counts as used, so no Time card, stack or way in shows it again (at any size)" do
    component = NexusCcs::ExploreComponent.new(overview: overview)
    pick = HomeLookCloser::Pick.new(id: "emu-9", title: "A bronze lyre", maker: nil, image: "https://dam.example/images/0000_013_1_pf.jpg?w=1600",
                                    tint: nil, crops: [])
    component.instance_variable_set(:@look_closer, pick)

    assert_not component.fresh?("https://dam.example/images/0000_013_1_pf.jpg?w=1000")
    assert component.fresh?("https://dam.example/images/another.jpg")
  end

  test "with no Look closer today, every picture is free" do
    component = NexusCcs::ExploreComponent.new(overview: overview)
    component.instance_variable_set(:@look_closer, nil)

    assert component.fresh?("https://dam.example/images/0000_013_1_pf.jpg")
  end

  test "with no record types, places or times, those sections are left out without leaving a heading behind" do
    render_inline NexusCcs::ExploreComponent.new(overview: empty_overview([ tile("University Art Collection", 1, 1) ]))

    assert_selector "section.explore h2", text: "Explore the collections"
    assert_no_selector "section.explore-kinds, section.home-places, section.explore-periods"
  end
end
