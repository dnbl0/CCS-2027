require "test_helper"

# The Places page (browse/places), after Google Arts & Culture's Places: "All", a wall of pictured places, and "A–Z", every place by letter
class PlacesPageTest < ActionDispatch::IntegrationTest
  def seed_places(values) = Rails.cache.write("browse_hubs/v1/places", values, expires_in: 1.day)

  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @cache }

  test "All is the default: tabs for All and A–Z, the filter, a wall of places with pictures and their full counts, and the way to every place" do
    wall = [ { "label" => "Australia", "count" => 532, "image" => { "id" => "emu-1", "title" => "A tree", "path" => "https://unimelbourne.widen.net/content/a/jpeg/a.jpeg?w=1000&u=x", "width" => nil, "height" => nil } } ]
    Rails.cache.write(SuppressedRecord.cache_key("browse_cards/v3/places/wall"), wall, expires_in: 1.day)
    seed_places([ [ "Australia", 8058 ], [ "Japan", 193 ] ])

    get "/browse/places"

    assert_response :success
    assert_select "h1", "Places"
    assert_select "nav.places-views a[aria-current=page]", "All"
    assert_select "nav.places-views a[href=?]", "/browse/places?view=az", text: "A–Z"
    assert_select "form[role=search] input[name=filter]"
    assert_select "ul.justified.places-wall[data-controller=justified] li a.places-wall__tile[href*='production_place_ssim']" do
      assert_select "img[alt=''][src*='w=600']" # a smaller rendition of the DAM picture
      assert_select ".places-wall__name", "Australia"
      assert_select ".places-wall__count", "8,058 records" # every record, as the A–Z list counts them, not only the pictured ones
    end
    assert_select "a[href=?]", "/browse/places?view=az", text: /See every place, A–Z \(2\)/
  end

  test "A–Z: the letters across the top and the list of every place" do
    seed_places([ [ "Australia", 8058 ], [ "Japan", 193 ] ])
    get "/browse/places", params: { view: "az" }

    assert_response :success
    assert_select "nav.places-views a[aria-current=page]", "A–Z"
    assert_select "nav.places-letters a[aria-current=page]", "Most records"
    assert_select "nav.places-letters a[href=?]", "/browse/places?letter=A", text: "A"
    assert_equal [ "Australia 8,058 records", "Japan 193 records" ], css_select("a.places-list__link").map { |a| a.text.squish }
    assert_select "ul.places-wall", count: 0
  end
end
