# frozen_string_literal: true

require "test_helper"

class ExploreComponentTest < ViewComponent::TestCase
  IMAGE = ExploreEntryPoints::Image.new(id: "emu-9", title: "A bronze lyre", path: "/digital-assets/thumbs/0000_013_1_pf.jpg", width: 400, height: 300)

  def group(id, heading, image: nil)
    ExploreEntryPoints::Group.new(id: id, heading: heading, image: image,
      items: [ ExploreEntryPoints::Item.new("lyre", 1200, BrowseHubs.query("object_type_ssim", "lyre")) ])
  end

  def groups(image: nil) = [ group("object-type", "Object type", image: image), group("place", "Place"), group("time", "Time") ]

  test "the Sublink menu: an h2, then a bold h3 and a list of arrow links for each group, with the count as the description" do
    render_inline NexusCcs::ExploreComponent.new(groups: groups)

    assert_selector "section.explore[aria-labelledby=explore-title] h2#explore-title", text: "Explore the collections"
    assert_selector "h3.explore__heading", count: 3
    assert_selector "h3#explore-object-type + ul.explore__list[aria-labelledby=explore-object-type]"
    assert_selector "a.explore__link .explore__label", text: "Lyre"
    assert_selector "a.explore__link .explore__count", text: "1,200 records"
    assert_selector "a.arrow-link.explore__all[href='/browse/object-types']", text: "See all object types"
    assert_selector "a.explore__all[href='/browse/periods']", text: "See all periods"
  end

  test "a group with an example image shows it whole, 16:9, lazy, sized, with an empty alt because the caption is the link text" do
    render_inline NexusCcs::ExploreComponent.new(groups: groups(image: IMAGE))

    assert_selector "figure.explore__figure", count: 1
    assert_selector "figure a.explore__figure-link[href='/catalog/emu-9'] figcaption", text: "A bronze lyre"
    assert_selector "img.explore__image[alt=''][loading=lazy][width='400'][height='300'][src*='0000_013_1_pf.jpg']"
  end

  test "a group with no image is text only" do
    render_inline NexusCcs::ExploreComponent.new(groups: groups)

    assert_no_selector "img"
    assert_no_selector "figure"
  end

  test "nothing renders without groups" do
    render_inline NexusCcs::ExploreComponent.new(groups: [])

    assert_no_selector "section"
  end
end
