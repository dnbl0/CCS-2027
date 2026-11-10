require "test_helper"
require_relative "../support/stub_records"

# CCS-425: a media file replaced under the same name shows without a manual purge. The addresses the pages give carry a version
# token (AssetVersion) that changes with the file; the static files revalidate (ETag, Last-Modified, 304); and none of it
# reaches a record whose assets are withheld. docs/media-refresh.md says what this cannot do.
class MediaRefreshTest < ActionDispatch::IntegrationTest
  include StubRecords

  TOKENED = /\?v=\h+/

  setup { AssetVersion.reset! }

  def open_record = stub_document("open-1", "thumbnail_path_ssi" => OPEN_THUMBS.first)
  def replaceable_record = stub_document("open-1", "digital_asset_large_paths_ssim" => [ temp_file ], "digital_asset_paths_ssim" => [ temp_file ])
  def withheld = stub_document("icip-1", licence: "ICIP Rights", "thumbnail_path_ssi" => OPEN_THUMBS.first)
  def sensitive = stub_document("sens-1", "restrictions_tsi" => [ "Culturally sensitive images" ], "thumbnail_path_ssi" => OPEN_THUMBS.first)

  # Parallel test processes share public/, so the file that is replaced here is this test's own copy, removed afterwards
  def temp_file
    @temp_file ||= begin
      name = "ccs425-#{Process.pid}-#{SecureRandom.hex(4)}.jpg"
      FileUtils.cp(Rails.public_path.join(OPEN_LARGE.first.delete_prefix("/")), Rails.public_path.join("digital-assets/large", name))
      "/digital-assets/large/#{name}"
    end
  end

  teardown do
    FileUtils.rm_f(Rails.public_path.join(@temp_file.delete_prefix("/"))) if @temp_file
    AssetVersion.reset!
  end

  # Changes a file the way a replacement does
  def replace(path)
    file = Rails.public_path.join(path.delete_prefix("/"))
    File.binwrite(file, File.binread(file) + "\n")
    File.utime(Time.now + 3600, Time.now + 3600, file)
    AssetVersion.reset!
  end

  def manifest_image_id = JSON.parse(response.body).dig("items", 0, "items", 0, "items", 0, "body", "id")

  # --- The static files ---

  test "a media file is sent with a validator and answers a repeat request with 304" do
    path = temp_file
    get path
    assert_response :success
    assert_equal "public, max-age=0, must-revalidate", response.headers["Cache-Control"]
    assert response.headers["ETag"].present? || response.headers["Last-Modified"].present?, "needs ETag or Last-Modified"

    headers = response.headers["ETag"] ? { "If-None-Match" => response.headers["ETag"] } : { "If-Modified-Since" => response.headers["Last-Modified"] }
    get path, headers: headers
    assert_response :not_modified
  end

  test "a replaced file is sent again, not as 304" do
    path = temp_file
    get path
    validators = response.headers.slice("ETag", "Last-Modified")
    assert validators.any?

    replace(path)
    get path, headers: { "If-None-Match" => validators["ETag"], "If-Modified-Since" => validators["Last-Modified"] }.compact
    assert_response :success
  end

  test "a versioned address is cached for a year" do
    get AssetVersion.url(temp_file)
    assert_response :success
    assert_equal "public, max-age=31536000, immutable", response.headers["Cache-Control"]
  end

  # --- The pages ---

  test "the manifest names the image by an address that changes with the file" do
    with_records(replaceable_record) { get "/catalog/open-1/manifest.json" }
    assert_response :success
    image = manifest_image_id
    assert_match TOKENED, image
    assert_match TOKENED, JSON.parse(response.body).dig("thumbnail", 0, "id")
    etag = response.headers["ETag"]

    with_records(replaceable_record) { get "/catalog/open-1/manifest.json", headers: { "If-None-Match" => etag } }
    assert_response :not_modified

    replace(temp_file)
    with_records(replaceable_record) { get "/catalog/open-1/manifest.json", headers: { "If-None-Match" => etag } }
    assert_response :success
    assert_not_equal image, manifest_image_id
  end

  test "the embed and oEmbed thumbnail carry the token" do
    with_records(open_record) { get "/embed/records/open-1" }
    assert_response :success
    assert_select "img[src*='#{OPEN_THUMBS.first}?v=']"

    with_records(open_record) { get "/oembed", params: { url: "http://www.example.com/catalog/open-1", format: "json" } }
    assert_response :success
    assert_match TOKENED, JSON.parse(response.body)["thumbnail_url"]
  end

  test "the comparison page's images carry the token" do
    with_records(open_record) { get "/compare", params: { record: "open-1" } }
    assert_response :success
    assert_select "img[src*='?v=']"
  end

  test "a withheld or unchosen sensitive record shows no asset path, versioned or not, anywhere" do
    [ withheld, sensitive ].each do |record|
      with_records(record) do
        get "/embed/records/#{record.id}"
        assert_not_includes response.body, "/digital-assets/", record.id
        get "/compare", params: { record: record.id }
        assert_not_includes response.body, "/digital-assets/", record.id
        get "/catalog/#{record.id}/manifest.json"
        assert_response :not_found
        assert_not_includes response.body, "/digital-assets/", record.id
      end
    end
  end

  test "results pages carry the token (the real index)" do
    needs_solr
    get "/catalog", params: { q: "", per_page: 20 }
    follow_redirect! if response.redirect?
    assert_response :success
    thumbs = css_select("img").map { |img| img["src"] }.grep(%r{/digital-assets/})
    skip "no record with an image in this index" if thumbs.empty?

    assert thumbs.all? { |src| src.match?(TOKENED) }, thumbs.inspect
  end
end
