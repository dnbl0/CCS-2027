require "test_helper"
require_relative "../support/stub_records"
require_relative "../support/env_override"

# The embed pages (/embed/*) and oEmbed: framable, noindex, tier-safe, and nothing of the visitor or the owner. The records are
# stubbed (RecordLookup), so these run without Solr; the last tests read the real core.
class EmbedsTest < ActionDispatch::IntegrationTest
  include StubRecords
  include EnvOverride

  THUMB = "/digital-assets/thumbs/x.jpg".freeze

  def open_record(**extra)
    stub_document("open-1", "creator_display_ssim" => [ "Judy Mengil (b.1954)" ], "production_date_ssim" => [ "2016" ], "thumbnail_path_ssi" => THUMB, **extra)
  end

  def withheld_record = stub_document("icip-1", licence: "ICIP Rights", "thumbnail_path_ssi" => "/digital-assets/thumbs/icip.jpg")

  def sensitive_record
    stub_document("sens-1", "restrictions_tsi" => [ "Culturally sensitive images" ], "thumbnail_path_ssi" => "/digital-assets/thumbs/sens.jpg")
  end

  # --- Framing and robots headers ---

  test "an embed page can be framed by any site by default, and is the only kind of page that can" do
    with_records(open_record) { get "/embed/records/open-1" }

    assert_response :success
    assert_nil response.headers["X-Frame-Options"]
    assert_equal "frame-ancestors *", response.headers["Content-Security-Policy"].split("; ").last
    assert_nil response.headers["Content-Security-Policy-Report-Only"], "the enforced policy replaces the report-only one"

    [ "/", "/help", "/lists", "/catalog", "/privacy", "/oembed?url=x" ].each do |path|
      get path
      assert_equal "SAMEORIGIN", response.headers["X-Frame-Options"], "#{path} must not be framable" unless path.start_with?("/oembed")
      assert_includes response.headers["Content-Security-Policy-Report-Only"].to_s, "frame-ancestors 'self'", path
      assert_nil response.headers["Content-Security-Policy"], path
    end
  end

  test "EMBED_FRAME_ANCESTORS limits the sites that may frame an embed, enforced" do
    with_env("EMBED_FRAME_ANCESTORS" => "https://museum.example.org") do
      with_records(open_record) { get "/embed/records/open-1" }
    end

    assert_nil response.headers["X-Frame-Options"]
    assert_includes response.headers["Content-Security-Policy"], "frame-ancestors 'self' https://museum.example.org"
  end

  test "embeds are noindex and nofollow whatever the indexing setting, in the header and the head" do
    with_env("SEO_INDEXING" => "on") { with_records(open_record) { get "/embed/records/open-1" } }

    assert_match(/\Anoindex, nofollow/, response.headers["X-Robots-Tag"])
    assert_match(/\Anoindex, nofollow/, css_select("meta[name=robots]").first["content"])
    assert_empty css_select("link[rel=canonical]")
  end

  test "an embed sets no cookie, runs no script and loads only the site's own files" do
    with_records(open_record) { get "/embed/records/open-1" }

    assert_nil response.headers["Set-Cookie"]
    assert_select "script", count: 0
    assert_select "form", count: 0
    assert_select "iframe", count: 0
    css_select("[src],[href]").each { |element| assert_no_match(%r{\Ahttps?://(?!www\.example)}i, element["src"].to_s) }
  end

  # --- A record ---

  test "a record's card has its title, creator, date, licence, the thumbnail, a link back to the record and the attribution" do
    with_records(open_record) { get "/embed/records/open-1" }

    assert_response :success
    assert_select "html[lang=en]"
    assert_select "title", text: /Title of open-1/
    assert_select "main h1 a[href$='/catalog/open-1'][target=_blank][rel~=noopener]", text: /Title of open-1/
    assert_select "h1 a .visually-hidden", text: /opens in a new tab/
    assert_select "main", text: /Judy Mengil \(b\.1954\) · 2016/
    assert_select "main", text: /Licence: Public domain - Copyright expired/
    assert_select "main img[src='#{THUMB}'][alt='']"
    assert_select "main a[href$='/catalog/open-1']", text: /View the full record/
    assert_select "footer a[href$='/'][target=_blank]", text: "Collections Navigator"
    assert_select "footer", text: /University of Melbourne/
    assert_select "main .embed-card__notice", count: 0
  end

  test "a record with no licence says so" do
    with_records(stub_document("nolic-1", "licence_type_ssim" => [])) { get "/embed/records/nolic-1" }

    assert_select "main", text: /No licence recorded/
  end

  test "a withheld record shows its notice and no image, and its asset paths appear nowhere" do
    with_records(withheld_record) { get "/embed/records/icip-1" }

    assert_response :success
    assert_select "img", count: 0
    assert_select ".embed-card__notice", text: /available on request/
    assert_not_includes response.body, "icip.jpg"
    assert_not_includes response.body, "digital-assets"
  end

  test "a sensitive record shows its notice and no image, and nothing the visitor chose brings it back" do
    with_records(sensitive_record) do
      post "/catalog/sens-1/sensitivity", params: { choice: "view" }
      get "/embed/records/sens-1"
    end

    assert_select "img", count: 0
    assert_select ".embed-card__notice", text: /may contain sensitive material/
    assert_not_includes response.body, "sens.jpg"
    assert_not_includes response.body, "digital-assets"
  end

  test "a record that is not in the index is a 404 that can still be framed, not the site's error page" do
    with_records(open_record) { get "/embed/records/nope-1" }

    assert_response :not_found
    assert_nil response.headers["X-Frame-Options"]
    assert_select "h1", text: "Not available"
    assert_select "script", count: 0
  end

  test "a record id with dots and a very long one are handled" do
    with_records(stub_document("vernon-MHM2014.191")) { get "/embed/records/vernon-MHM2014.191" }
    assert_response :success

    get "/embed/records/#{'x' * 300}"
    assert_response :not_found
  end

  test "an unreachable index gives a 503 inside the frame" do
    original = RecordLookup.instance_method(:find_record)
    RecordLookup.send(:define_method, :find_record) { |_id| raise Faraday::ConnectionFailed, "down" }
    RecordLookup.send(:private, :find_record)
    begin
      get "/embed/records/open-1"
    ensure
      RecordLookup.send(:define_method, :find_record, original)
      RecordLookup.send(:private, :find_record)
    end

    assert_response :service_unavailable
    assert_nil response.headers["X-Frame-Options"]
  end

  # --- A gallery ---

  def shared_list(ids)
    list = User.create!.lists.create!(name: "Strings", description: "Instruments we like")
    ids.each { |id| list.list_items.create!(document_id: id) }
    list.share!
  end

  test "a gallery's card lists its records without owner or images that may not be shown, and links to the gallery" do
    list = shared_list(%w[open-1 icip-1 sens-1 gone-1])
    owner = User.find(list.user_id)

    with_records(open_record, withheld_record, sensitive_record) { get "/embed/galleries/#{list.share_token}" }

    assert_response :success
    assert_nil response.headers["X-Frame-Options"]
    assert_match(/\Anoindex, nofollow/, response.headers["X-Robots-Tag"])
    assert_select "h1 a[href$='/galleries/#{list.share_token}']", text: /Strings/
    assert_select "main", text: /Instruments we like/
    assert_select ".embed-gallery li", count: 3
    assert_select ".embed-gallery img[src='#{THUMB}']", count: 1
    assert_select ".embed-gallery img", count: 1
    assert_select ".embed-gallery__image--none", count: 2
    assert_not_includes response.body, "icip.jpg"
    assert_not_includes response.body, "sens.jpg"
    assert_no_match(/Guest #{owner.id}\b/, response.body)
    assert_select "main a[href$='/galleries/#{list.share_token}']", text: /View the gallery \(4 records\)/
  end

  test "a gallery's card shows at most the first dozen records, however many there are" do
    ids = (1..30).map { |n| "rec-#{n}" }
    list = shared_list(ids)

    with_records(*ids.map { |id| stub_document(id) }) { get "/embed/galleries/#{list.share_token}" }

    assert_select ".embed-gallery li", count: EmbedsController::GALLERY_RECORDS
    assert_select "main a", text: /View the gallery \(30 records\)/
  end

  test "a wrong or revoked gallery token is a 404 in the frame" do
    list = shared_list(%w[open-1])
    token = list.share_token
    list.unshare!

    [ token, "a" * 32 ].each do |bad|
      with_records(open_record) { get "/embed/galleries/#{bad}" }
      assert_response :not_found, bad
      assert_nil response.headers["X-Frame-Options"]
      assert_not_includes response.body, "Strings"
    end
    get "/embed/galleries/short"
    assert_response :not_found
  end

  # --- oEmbed ---

  def oembed(url, **params)
    get "/oembed", params: { url: url, format: "json" }.merge(params)
    response.parsed_body if response.successful?
  end

  test "oEmbed describes a record as a rich embed with an iframe, its title, provider and size" do
    json = with_records(open_record) { oembed("http://www.example.com/catalog/open-1") }

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal "1.0", json["version"]
    assert_equal "rich", json["type"]
    assert_equal "Title of open-1", json["title"]
    assert_equal "Collections Navigator, University of Melbourne", json["provider_name"]
    assert_equal EmbedCode::RECORD_WIDTH, json["width"]
    assert_operator json["height"], :>, 0
    iframe = Nokogiri::HTML5.fragment(json["html"]).at("iframe")
    assert_equal "http://www.example.com/embed/records/open-1", iframe["src"]
    assert_match(/Title of open-1/, iframe["title"])
    assert_equal json["width"].to_s, iframe["width"]
    assert_equal "http://www.example.com#{THUMB}", json["thumbnail_url"]
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
  end

  test "oEmbed does not name a withheld or sensitive record, in the title or the iframe's title" do
    [ withheld_record, sensitive_record ].each do |record|
      json = with_records(record) { oembed("http://www.example.com/catalog/#{record.id}") }

      assert_equal EmbedCode::GENERIC_TITLE, json["title"], record.id
      assert_not_includes json.to_json, Array(record["title_tsim"]).first.to_s, record.id
      assert_equal "#{EmbedCode::GENERIC_TITLE} - #{EmbedCode::PROVIDER}", Nokogiri::HTML5.fragment(json["html"]).at("iframe")["title"]
    end
  end

  test "oEmbed gives no thumbnail for a withheld or sensitive record, and a taller frame for its notice" do
    [ withheld_record, sensitive_record ].each do |record|
      json = with_records(record) { oembed("http://www.example.com/catalog/#{record.id}") }

      assert_response :success
      assert_not json.key?("thumbnail_url"), record.id
      assert_not_includes json.to_json, "digital-assets"
    end
  end

  test "oEmbed keeps within maxwidth and maxheight" do
    json = with_records(open_record) { oembed("http://www.example.com/catalog/open-1", maxwidth: "300", maxheight: "150") }

    assert_equal [ 300, 150 ], [ json["width"], json["height"] ]
  end

  test "oEmbed describes a shared gallery, and says nothing of its owner" do
    list = shared_list(%w[open-1])
    json = oembed("http://www.example.com/galleries/#{list.share_token}")

    assert_response :success
    assert_equal "Strings", json["title"]
    assert_equal "rich", json["type"]
    assert_includes json["html"], "/embed/galleries/#{list.share_token}"
    assert_not json.key?("author_name")
    assert_not json.key?("thumbnail_url")
  end

  test "oEmbed refuses a revoked gallery, an unknown record, another site's address, a malformed address and an unsupported format" do
    list = shared_list(%w[open-1])
    token = list.share_token
    list.unshare!

    [ "http://www.example.com/galleries/#{token}", "http://www.example.com/catalog/nope-1", "http://evil.example.net/catalog/open-1",
      "not a url", "ftp://www.example.com/catalog/open-1", "http://www.example.com/help", "", "http://www.example.com/catalog/open-1/citation" ].each do |url|
      with_records(open_record) { get "/oembed", params: { url: url, format: "json" } }
      assert_response :not_found, url
    end
    get "/oembed"
    assert_response :not_found

    with_records(open_record) { get "/oembed", params: { url: "http://www.example.com/catalog/open-1", format: "xml" } }
    assert_response :not_implemented
  end

  test "oEmbed cannot be used to read a page of this site that is not a record or a gallery" do
    get "/oembed", params: { url: "http://www.example.com/lists/1", format: "json" }
    assert_response :not_found
  end

  # --- The real index ---

  test "a record page offers its oEmbed address for discovery and a Share and embed button with the iframe code" do
    needs_solr
    get "/catalog/emu-400198"

    assert_response :success
    link = css_select("link[rel=alternate][type='application/json+oembed']").first
    assert link, "discovery link"
    assert_match(%r{/oembed\?format=json&url=}, link["href"])
    assert_select ".record-summary__share .share__button", text: /Share and embed/
    assert_select "dialog.share__dialog textarea", count: 2
    assert_select "dialog.share__dialog input[readonly][value$='/catalog/emu-400198']"
    assert_select "dialog.share__dialog .share__code", text: /<iframe src="[^"]*\/embed\/records\/emu-400198" title="[^"]*" width="480"/
  end

  test "the embed and oEmbed of a real record with an image give its thumbnail; a real withheld one does not" do
    needs_solr
    get "/embed/records/emu-400198"
    assert_response :success
    assert_select "main img[src*='/digital-assets/thumbs/']"

    ids = Blacklight.default_index.connection.get("select", params: { q: "licence_type_ssim:\"ICIP Rights\" AND thumbnail_path_ssi:*", fl: "id,thumbnail_path_ssi", rows: 1 })
                    .dig("response", "docs")
    skip "no ICIP record with an image in this index" if ids.empty?

    get "/embed/records/#{ids.first['id']}"
    assert_select "img", count: 0
    assert_not_includes response.body, ids.first["thumbnail_path_ssi"]
  end
end
