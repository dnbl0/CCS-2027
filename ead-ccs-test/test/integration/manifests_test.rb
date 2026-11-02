require "test_helper"
require_relative "../support/stub_records"

# CCS-57: /catalog/:id/manifest.json per access tier. The records are stubbed (no Solr needed); their images are real files, so
# the canvases have sizes.
class ManifestsTest < ActionDispatch::IntegrationTest
  include StubRecords

  def manifest_for(document)
    with_records(document) { get "/catalog/#{document.id}/manifest.json" }
  end

  test "an open record gives a Presentation 3.0 manifest of its images, open to other sites, cached for an hour" do
    manifest_for(stub_document("open-1"))

    assert_response :success
    assert_match %r{\Aapplication/ld\+json;\s*profile="http://iiif.io/api/presentation/3/context.json"}, response.headers["Content-Type"]
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
    assert_match(/public/, response.headers["Cache-Control"])
    assert_match(/max-age=3600/, response.headers["Cache-Control"])
    assert_nil response.headers["Set-Cookie"], "a public, cacheable response sets no cookie"
    assert_match(/noindex/, response.headers["X-Robots-Tag"].to_s)

    json = JSON.parse(response.body)
    assert_equal "http://iiif.io/api/presentation/3/context.json", json["@context"]
    assert_equal "http://www.example.com/catalog/open-1/manifest.json", json["id"]
    assert_equal 2, json["items"].size
    assert_equal "http://creativecommons.org/publicdomain/mark/1.0/", json["rights"]
    assert_includes response.body, "http://www.example.com#{StubRecords::OPEN_LARGE.first}"
  end

  test "a view-only record also gives its images, with the licence as the required statement" do
    manifest_for(stub_document("view-1", licence: "Copyright - Current"))

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json["items"].size
    assert_equal "http://rightsstatements.org/vocab/InC/1.0/", json["rights"]
  end

  test "a withheld record has no manifest, and nothing of its images is in the answer" do
    manifest_for(stub_document("request-1", licence: "ICIP Rights"))

    assert_response :not_found
    assert_not_includes response.body, "/digital-assets/"
    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  test "a record that is not in the index has no manifest" do
    with_records { get "/catalog/nothing/manifest.json" }

    assert_response :not_found
  end

  test "a sensitive record has no manifest until the visitor chooses to view it; then it is private, with no CORS" do
    sensitive = stub_document("sensitive-1", restrictions_tsi: [ "Culturally sensitive images" ])
    manifest_for(sensitive)
    assert_response :not_found
    assert_not_includes response.body, "/digital-assets/"

    with_records(sensitive) do
      post "/catalog/sensitive-1/sensitivity", params: { choice: "hide" }
      get "/catalog/sensitive-1/manifest.json"
      assert_response :not_found

      post "/catalog/sensitive-1/sensitivity", params: { choice: "view" }
      get "/catalog/sensitive-1/manifest.json"
    end
    assert_response :success
    assert_match(/private/, response.headers["Cache-Control"])
    assert_match(/no-store/, response.headers["Cache-Control"])
    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  test "a record whose images the manifest cannot size has no manifest" do
    manifest_for(stub_document("gone-1", "digital_asset_large_paths_ssim" => [ "/digital-assets/large/not-there.jpg" ]))

    assert_response :not_found
  end
end
