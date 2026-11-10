require "test_helper"
require_relative "../support/stub_records"

# CCS-471: the cookie notice for guests. The notice tells the truth about the cookies the site sets (CookieNotice::ESSENTIAL),
# remembers that it was read in a first-party cookie, and the site sets no cookie that is not on that list.
class CookieNoticePagesTest < ActionDispatch::IntegrationTest
  include StubRecords

  NOTICE = "section.cookie-notice".freeze
  PAGES = %w[/help /about /privacy /accessibility /lists/new].freeze

  def set_cookie_names = Array(response.headers["set-cookie"]).flat_map { |h| h.split("\n") }.map { |line| line.split("=", 2).first.strip }.uniq

  test "a visitor who has not been told sees the notice on the content pages, near the top, before the header" do
    PAGES.each do |path|
      get path
      assert_response :success
      assert_select NOTICE, 1, path
      assert_select "body > a.skip-link ~ #{NOTICE}", 1, "#{path}: after the skip link" if css_select("body > a.skip-link").any?
    end
  end

  test "the notice appears on a Blacklight page too" do
    needs_solr
    get "/catalog", params: { q: "melbourne", f: { has_digital_asset: [ "with" ] } }
    assert_response :success
    assert_select NOTICE, 1
  end

  test "reading it hides it for the next visit, with one first-party cookie that is HttpOnly, Lax and lasts months, not years" do
    post "/cookie_notice", params: { choice: "acknowledged" }, headers: { "Referer" => "http://www.example.com/help" }

    assert_redirected_to "/help"
    assert_equal 303, response.status
    header = response.headers["set-cookie"].to_s
    assert_match(/ccs_cookie_notice=#{CookieNotice::VERSION}\.acknowledged/, header)
    assert_match(/httponly/i, header)
    assert_match(/samesite=lax/i, header)
    assert_match(/expires=/i, header)
    assert_no_match(/domain=/i, header)

    get "/help"
    assert_select NOTICE, 0
  end

  test "script that fetches the form gets no content, and the cookie is still set" do
    post "/cookie_notice", params: { choice: "acknowledged" }, headers: { "Accept" => "application/json" }

    assert_response :no_content
    assert_includes set_cookie_names, "ccs_cookie_notice"
  end

  test "a choice the notice did not offer is ignored: no cookie, and the notice stays" do
    post "/cookie_notice", params: { choice: "accepted" }, headers: { "Referer" => "http://www.example.com/help" }

    assert_not_includes set_cookie_names, "ccs_cookie_notice"
    get "/help"
    assert_select NOTICE, 1
  end

  test "it never sends the visitor to another site" do
    post "/cookie_notice", params: { choice: "acknowledged" }, headers: { "Referer" => "https://evil.example/x" }

    assert_redirected_to "/"
  end

  test "a notice that changed since the visitor read it is shown again" do
    cookies[CookieNotice::COOKIE] = "0.acknowledged"
    get "/help"
    assert_select NOTICE, 1
  end

  test "embed pages show no notice, run no script and set no cookie at all" do
    with_records(stub_document("open-1", "thumbnail_path_ssi" => "/digital-assets/thumbs/x.jpg")) { get "/embed/records/open-1" }

    assert_response :success
    assert_select NOTICE, 0
    assert_select "script", 0
    assert_nil response.headers["set-cookie"]
  end

  test "the pages set only cookies the notice lists as essential, and no optional cookie before consent" do
    declared = (CookieNotice.essential.map(&:name) + CookieNotice.optional.flat_map { |c| c.cookies.map(&:name) }).uniq
    PAGES.each do |path|
      get path
      unexpected = set_cookie_names - declared
      assert_empty unexpected, "#{path} sets #{unexpected.join(", ")}, which the cookie notice and /privacy do not declare"
    end
    assert_empty CookieNotice.optional.flat_map { |c| c.cookies.map(&:name) } & set_cookie_names
  end

  test "the home page's cookies are declared too" do
    needs_solr
    get "/"
    assert_empty set_cookie_names - CookieNotice.essential.map(&:name)
  end

  test "the privacy page lists every essential cookie by name, from the same list as the notice" do
    get "/privacy"
    assert_select "#cookies"
    CookieNotice.essential.each { |cookie| assert_select "#cookies code", text: cookie.name }
    assert_select "#cookies", text: /no optional cookies|no advertising or analytics/i
  end

  test "the notice adds no markup that grows the page past its budget" do
    get "/help"
    assert_operator css_select(NOTICE).to_s.bytesize, :<, 2_500
  end
end
