# frozen_string_literal: true

require "test_helper"

class ExploreComponentTest < ViewComponent::TestCase
  IMAGE = ExploreEntryPoints::Image.new(id: "emu-9", title: "A bronze lyre", path: "/digital-assets/thumbs/0000_013_1_pf.jpg", width: 400, height: 300)

  def tile(label, count, tint, image: nil) = ExploreEntryPoints::Tile.new(label: label, count: count, query: BrowseHubs.query("collection_ssim", label), image: image, tint: tint)

  def overview(image: nil, indigenous_image: nil)
    ExploreEntryPoints::Overview.new(
      [ tile("University Art Collection", 14_537, 1, image: image), tile("Indigenous Collections", 1540, 2, image: indigenous_image), tile("Medical History Museum", 1, 3) ],
      [ ExploreEntryPoints::Link.new("Paintings", 2555, Browse.search_query("classification_ssim", [ "paintings" ])),
        ExploreEntryPoints::Link.new("Prints and drawings", 7192, Browse.search_query("classification_ssim", %w[prints drawings])) ],
      [ ExploreEntryPoints::Link.new("Australia", 8056, BrowseHubs.query("production_place_ssim", "Australia")) ],
      [ ExploreEntryPoints::Link.new("1900s", 5000, BrowseHubs.period_query(1900, 1999)) ]
    )
  end

  test "an h2, then a tile for each collection: the whole tile is one link with the h3 and the exact count inside it" do
    render_inline NexusCcs::ExploreComponent.new(overview: overview)

    assert_selector "section.explore[aria-labelledby=explore-title] h2#explore-title", text: "Explore the collections"
    assert_selector "ul.explore__tiles[aria-label='Browse by collection'] li.explore__tile", count: 3
    assert_selector "li.explore__tile > a.explore__tile-link h3.explore__tile-title", text: "University Art Collection"
    assert_selector "a.explore__tile-link .explore__tile-count", text: "14,537 records"
    assert_selector "a.explore__tile-link .explore__tile-count", text: "1 record", exact_text: true
    assert_selector "a.explore__tile-link[href*='f%5Bcollection_ssim%5D%5B%5D=University+Art+Collection'][href*='any_assets=1']"
    assert_selector "li.explore__tile--tint-2"
  end

  test "a tile with no picture is the designed face: a tint and a letter hidden from assistive technology, and no img at all" do
    render_inline NexusCcs::ExploreComponent.new(overview: overview)

    assert_no_selector "img"
    assert_selector ".explore__face[aria-hidden=true] .explore__monogram", text: "UA"
    assert_no_selector ".explore__face--image"
  end

  test "a tile with an example image shows it whole, lazy, sized, with an empty alt because the title is the link text" do
    render_inline NexusCcs::ExploreComponent.new(overview: overview(image: IMAGE))

    assert_selector "img.explore__image", count: 1
    assert_selector "li.explore__tile--tint-1 img.explore__image[alt=''][loading=lazy][width='400'][height='300'][src*='0000_013_1_pf.jpg']"
    assert_selector "li.explore__tile--tint-1 a h3", text: "University Art Collection"
  end

  test "the Indigenous Collections tile is text only even when it is given an image" do
    render_inline NexusCcs::ExploreComponent.new(overview: overview(indigenous_image: IMAGE))

    assert_no_selector "img"
    assert_selector "li.explore__tile--tint-2 .explore__monogram", text: "IC"
  end

  test "an image path that is not a local file is not drawn" do
    remote = IMAGE.with(path: "https://example.org/x.jpg")
    render_inline NexusCcs::ExploreComponent.new(overview: overview(image: remote))

    assert_no_selector "img"
  end

  test "kinds of records are a plain list of links to the catalogue filters; a kind with several values is an any-of filter" do
    render_inline NexusCcs::ExploreComponent.new(overview: overview)

    assert_selector "h3#explore-kinds", text: "Kinds of records"
    assert_selector "ul[aria-labelledby=explore-kinds] a.explore__link", count: 2
    assert_selector "a.explore__link[href*='f%5Bclassification_ssim%5D%5B%5D=paintings']", text: "Paintings"
    assert_selector "a.explore__link[href*='f_inclusive%5Bclassification_ssim%5D%5B%5D=prints'][href*='f_inclusive%5Bclassification_ssim%5D%5B%5D=drawings']", text: "Prints and drawings"
    assert_selector ".explore__links--columns a", text: /\A[^0-9]+\z/ # no counts in the secondary lists
    assert_selector "a.explore__all[href='/browse/object-types']", text: "See all object types"
  end

  test "place and time are two disclosures, closed in the markup, each with a link to its browse page" do
    render_inline NexusCcs::ExploreComponent.new(overview: overview)

    assert_selector "h3", text: "Place and time"
    assert_selector "details.explore__disclosure[data-controller=explore-disclosure]:not([open])", count: 2
    assert_selector "details summary.explore__summary", text: "Places"
    assert_selector "details a.explore__link[href*='f%5Bproduction_place_ssim%5D%5B%5D=Australia']", text: "Australia", visible: :all
    assert_selector "details a.explore__link[href*='range%5Bdate_start_isi%5D%5Bbegin%5D=1900']", text: "1900s", visible: :all
    assert_selector "a.explore__all[href='/browse/places']", text: "See all places", visible: :all
    assert_selector "a.explore__all[href='/browse/periods']", text: "See all periods", visible: :all
  end

  test "nothing renders without anything to show" do
    render_inline NexusCcs::ExploreComponent.new(overview: ExploreEntryPoints::Overview.new([], [], [], []))

    assert_no_selector "section"
  end

  test "with only some groups, the others are left out without leaving a heading behind" do
    render_inline NexusCcs::ExploreComponent.new(overview: ExploreEntryPoints::Overview.new(overview.collections, [], [], []))

    assert_selector "li.explore__tile", count: 3
    assert_no_selector "h3", text: "Kinds of records"
    assert_no_selector "h3", text: "Place and time"
  end
end
