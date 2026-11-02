require "test_helper"

# CCS-227: a sensitive record's assets are hidden until the visitor chooses, the choice is kept for the session, and a form
# post does it without JavaScript. emu-406126 is a real :open record with an image; it is made "sensitive" here by stubbing
# the rule (no record in the index is both sensitive and has an image).
class SensitivityChoicesTest < ActionDispatch::IntegrationTest
  OPEN = "emu-406126"
  IMAGE = "/digital-assets/large/85827df9ab6c38d57468e763906aff80.jpg"

  # Replaces a module function for the block (Minitest 6 has no stub)
  def replacing(mod, name, impl)
    original = mod.method(name)
    mod.define_singleton_method(name) { |*args| impl.call(*args) }
    yield
  ensure
    mod.define_singleton_method(name, original)
  end

  def sensitive(&) = replacing(Sensitivity, :sensitive?, ->(document) { document.id == OPEN }, &)

  test "by default the page asks, and the image path is nowhere in the page" do
    sensitive { get "/catalog/#{OPEN}" }

    assert_response :success
    assert_select ".sensitivity-gate--ask form[action='/catalog/#{OPEN}/sensitivity']", count: 2
    assert_select ".digital-assets img", count: 0
    assert_not_includes response.body, IMAGE
  end

  test "View this item shows the image from then on, in this session, with a way to hide it again" do
    sensitive do
      post "/catalog/#{OPEN}/sensitivity", params: { choice: "view" }
      assert_redirected_to "/catalog/#{OPEN}#digital-assets"
      follow_redirect!

      assert_select ".sensitivity-gate--viewing [data-controller=focus-on-load]"
      assert_select "img[src='#{IMAGE}']"
      assert_select ".sensitivity-gate--viewing button", text: "Hide this item"

      get "/catalog/#{OPEN}"
      assert_select "img[src='#{IMAGE}']"
      assert_select "[data-controller=focus-on-load]", count: 0
    end
  end

  test "Do not view keeps the image hidden, and offers View this item" do
    sensitive do
      post "/catalog/#{OPEN}/sensitivity", params: { choice: "hide" }
      follow_redirect!

      assert_select ".sensitivity-gate--declined button", text: "View this item"
      assert_select ".digital-assets img", count: 0
      assert_not_includes response.body, IMAGE
    end
  end

  test "Hide this item takes back a choice to view" do
    sensitive do
      post "/catalog/#{OPEN}/sensitivity", params: { choice: "view" }
      post "/catalog/#{OPEN}/sensitivity", params: { choice: "hide" }
      get "/catalog/#{OPEN}"

      assert_select ".sensitivity-gate--declined"
      assert_not_includes response.body, IMAGE
    end
  end

  test "a record that is not sensitive has nothing to choose, and an unknown record is a 404" do
    post "/catalog/#{OPEN}/sensitivity", params: { choice: "view" }
    assert_response :not_found

    post "/catalog/no-such-record/sensitivity", params: { choice: "view" }
    assert_response :not_found
  end

  test "a sensitive record that is withheld stays withheld, and cannot be chosen into view" do
    sensitive do
      replacing(AccessPolicy, :tier, ->(_document) { :request }) do
        post "/catalog/#{OPEN}/sensitivity", params: { choice: "view" }
        assert_response :not_found

        get "/catalog/#{OPEN}"
        assert_not_includes response.body, IMAGE
      end
    end
  end

  test "a value other than view or hide changes nothing" do
    sensitive do
      post "/catalog/#{OPEN}/sensitivity", params: { choice: "<script>" }
      follow_redirect!
      assert_select ".sensitivity-gate--ask"
    end
  end

  test "the result card hides the thumbnail of a sensitive record, and shows it for any other" do
    get "/catalog", params: { q: "Grainger", f: { has_digital_asset: [ "with" ] }, view: "list" }
    assert_select ".result-card__media"

    replacing(Sensitivity, :sensitive?, ->(_document) { true }) do
      get "/catalog", params: { q: "Grainger", f: { has_digital_asset: [ "with" ] }, view: "list" }
    end
    assert_select ".result-card"
    assert_select ".result-card__media", count: 0
  end
end
