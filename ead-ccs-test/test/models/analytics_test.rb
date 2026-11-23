require "test_helper"

# CCS-53: analytics is Adobe's tag, configured by its address, and an optional cookie the visitor must accept first (CCS-471)
class AnalyticsTest < ActionDispatch::IntegrationTest
  URL = "https://assets.adobedtm.com/abc123/launch-def456.min.js".freeze

  teardown { ENV.delete("ADOBE_ANALYTICS_SCRIPT_URL") }

  test "unset, there is no analytics: no optional cookies, no choice, no tag" do
    assert_not Analytics.enabled?
    assert_empty CookieNotice.optional
    get "/help"
    assert_no_match(/adobedtm/, response.body)
  end

  test "set, analytics is an optional category the visitor is asked about, and the tag loads only after they accept" do
    ENV["ADOBE_ANALYTICS_SCRIPT_URL"] = URL
    assert_equal [ "analytics" ], CookieNotice.optional.map(&:key)
    assert CookieNotice.choosable?

    get "/help"
    assert_select "section.cookie-notice button[value=accepted]"
    assert_no_match(/adobedtm/, response.body) # not before an answer

    cookies[CookieNotice::COOKIE.to_s] = CookieNotice.value("declined")
    get "/help"
    assert_no_match(/adobedtm/, response.body)

    cookies[CookieNotice::COOKIE.to_s] = CookieNotice.value("accepted")
    get "/help"
    assert_select "script[src='#{URL}'][async]"
  end

  test "an address that is not an https script is ignored" do
    ENV["ADOBE_ANALYTICS_SCRIPT_URL"] = "http://example.com/x.js"
    assert_not Analytics.enabled?
  end
end
