require "test_helper"

# CCS-57: the IIIF Presentation 3.0 manifest, checked against the spec's required properties (no external validator)
class IiifManifestTest < ActiveSupport::TestCase
  BASE = "https://ccs.example.org"
  SIZES = ->(path) { path.end_with?("a.jpg") ? [ 2000, 1500 ] : (path.end_with?("b.png") ? [ 800, 1200 ] : nil) }

  def document(extra = {})
    SolrDocument.new({ "id" => "emu-1", "title_tsim" => [ "A portrait" ], "accession_number_ssim" => [ "13.0028" ],
                       "licence_type_ssim" => [ "Public domain - Copyright expired" ],
                       "digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg", "/digital-assets/large/b.png" ],
                       "digital_asset_paths_ssim" => [ "/digital-assets/thumbs/a.jpg", "/digital-assets/thumbs/b.png" ] }.merge(extra))
  end

  def build(extra = {})
    IiifManifest.new(RecordMedia.new(document(extra)), base_url: BASE, dimensions: SIZES)
  end

  def json(extra = {}) = JSON.parse(build(extra).as_json.to_json)

  def language_map?(value)
    value.is_a?(Hash) && value.any? && value.all? { |language, strings| language.is_a?(String) && strings.is_a?(Array) && strings.all?(String) }
  end

  def http_uri?(value) = value.is_a?(String) && value.match?(%r{\Ahttps?://\S+\z})

  test "the manifest has the properties the Presentation 3.0 spec requires of it" do
    manifest = json

    assert_equal "http://iiif.io/api/presentation/3/context.json", manifest["@context"]
    assert_equal "#{BASE}/catalog/emu-1/manifest.json", manifest["id"]
    assert_equal "Manifest", manifest["type"]
    assert language_map?(manifest["label"])
    assert_equal [ "A portrait" ], manifest["label"]["en"]
    assert_kind_of Array, manifest["items"]
    assert manifest["items"].any?
    assert language_map?(manifest["requiredStatement"]["label"])
    assert language_map?(manifest["requiredStatement"]["value"])
    assert_includes manifest["requiredStatement"]["value"]["en"].first, "Public domain - Copyright expired"
    manifest["metadata"].each { |pair| assert language_map?(pair["label"]) && language_map?(pair["value"]) }
    assert(manifest["provider"].all? { |agent| agent["type"] == "Agent" && http_uri?(agent["id"]) && language_map?(agent["label"]) })
  end

  test "each image is a canvas with a size, one page, and one painting annotation targeting the canvas" do
    manifest = json
    ids = []

    assert_equal 2, manifest["items"].size
    manifest["items"].each do |canvas|
      assert_equal "Canvas", canvas["type"]
      assert http_uri?(canvas["id"])
      assert_operator canvas["width"], :>, 0
      assert_operator canvas["height"], :>, 0
      page = canvas["items"].fetch(0)
      assert_equal "AnnotationPage", page["type"]
      annotation = page["items"].fetch(0)
      assert_equal "Annotation", annotation["type"]
      assert_equal "painting", annotation["motivation"]
      assert_equal canvas["id"], annotation["target"]
      body = annotation["body"]
      assert_equal "Image", body["type"]
      assert http_uri?(body["id"])
      assert_equal [ canvas["width"], canvas["height"] ], [ body["width"], body["height"] ]
      ids += [ canvas["id"], page["id"], annotation["id"] ]
    end
    assert_equal ids.uniq, ids, "ids are unique"
    assert_equal "#{BASE}/digital-assets/large/a.jpg", manifest["items"][0]["items"][0]["items"][0]["body"]["id"]
    assert_equal "image/png", manifest["items"][1]["items"][0]["items"][0]["body"]["format"]
    assert_equal [ "A portrait, image 2 of 2" ], manifest["items"][1]["label"]["en"]
  end

  test "a record that carries an IIIF info.json names the image service on the body" do
    manifest = json(MediaTypes::IIIF_INFO_FIELD => [ "https://iiif.example.org/a/info.json", "" ])
    first, second = manifest["items"].map { |canvas| canvas["items"][0]["items"][0]["body"] }

    assert_equal [ { "id" => "https://iiif.example.org/a", "type" => "ImageService3", "profile" => "level1" } ], first["service"]
    assert_nil second["service"]
  end

  test "rights is a URI when the licence maps to one, and the requiredStatement carries the licence either way" do
    assert_equal "http://creativecommons.org/publicdomain/mark/1.0/", json["rights"]
    assert_equal "http://rightsstatements.org/vocab/InC/1.0/", json("licence_type_ssim" => [ "Copyright - Current" ])["rights"]

    unmapped = json("licence_type_ssim" => [ "Reproduction Licence - Current" ])
    assert_not unmapped.key?("rights")
    assert_includes unmapped["requiredStatement"]["value"]["en"].first, "Reproduction Licence - Current"

    mixed = json("licence_type_ssim" => [ "Copyright", "Public domain - Copyright expired" ])
    assert_not mixed.key?("rights"), "two licences with different URIs have no one URI"
    assert_includes json("licence_type_ssim" => [])["requiredStatement"]["value"]["en"].first, "not stated"
  end

  test "an image whose size cannot be read is left out, and a record with none has no manifest" do
    manifest = IiifManifest.new(RecordMedia.new(document("digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg", "/digital-assets/large/missing.jpg" ])),
                                base_url: BASE, dimensions: SIZES)
    assert_equal 1, manifest.canvases.size

    none = IiifManifest.new(RecordMedia.new(document("digital_asset_large_paths_ssim" => [ "/digital-assets/large/missing.jpg" ])), base_url: BASE, dimensions: SIZES)
    assert_not none.any?
  end

  test "a withheld record's manifest has no canvases and no image address" do
    manifest = build("licence_type_ssim" => [ "ICIP Rights" ])

    assert_not manifest.any?
    assert_not_includes manifest.as_json.to_json, "/digital-assets/"
  end

  test "the id of a record with awkward characters is escaped" do
    assert_equal "#{BASE}/catalog/a%20b%2Fc/manifest.json", IiifManifest.new(RecordMedia.new(document("id" => "a b/c")), base_url: BASE, dimensions: SIZES).id
  end
end
