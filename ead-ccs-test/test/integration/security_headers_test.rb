require "test_helper"

# The response headers that protect a visitor (CCS-148). The Content-Security-Policy is still report-only; the test for it
# (content_security_policy_test.rb) says why, and the last test here is what must be true before it can be enforced.
class SecurityHeadersTest < ActionDispatch::IntegrationTest
  PAGES = %w[/ /help /about /accessibility /privacy /catalog/advanced /bookmarks].freeze

  test "every page is not framed by other sites, not sniffed, and sends a strict referrer policy" do
    PAGES.each do |path|
      get path

      assert_equal "SAMEORIGIN", response.headers["X-Frame-Options"], path
      assert_equal "nosniff", response.headers["X-Content-Type-Options"], path
      assert_equal "strict-origin-when-cross-origin", response.headers["Referrer-Policy"], path
      assert_equal "same-origin", response.headers["Cross-Origin-Opener-Policy"], path
    end
  end

  test "the permissions policy switches off the features the site never uses, and keeps full screen and copying for itself" do
    get "/"
    policy = response.headers["Permissions-Policy"].to_s

    %w[camera microphone geolocation payment usb].each { |feature| assert_includes policy, "#{feature}=()", feature }
    assert_includes policy, "fullscreen=(self)"
    assert_includes policy, "clipboard-write=(self)"
  end

  test "the policy restricts where pages may load from: no plug-ins, no other base, forms to the site and University search only" do
    get "/"
    policy = response.headers["Content-Security-Policy-Report-Only"].to_s

    assert_includes policy, "object-src 'none'"
    assert_includes policy, "base-uri 'self'"
    assert_includes policy, "frame-ancestors 'self'"
    assert_includes policy, "form-action 'self' https://search.unimelb.edu.au"
  end

  test "every inline script carries the page's nonce, so the policy can be enforced without breaking a page" do
    (PAGES + %w[/search_history /lists]).each do |path|
      get path
      nonce = response.headers["Content-Security-Policy-Report-Only"].to_s[/'nonce-([^']+)'/, 1]
      assert nonce, path
      css_select("script:not([src])").each do |script|
        next if script["type"].to_s.include?("json") # data blocks (JSON-LD, the importmap) are not executed as script

        assert_equal nonce, script["nonce"], "#{path}: inline script without the nonce: #{script.to_s[0, 80]}"
      end
    end
  end

  test "the access request form's personal details are kept out of the logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    logged = filter.filter("access_request" => { "name" => "A Person", "email" => "a@example.org", "organisation" => "Org", "purpose" => "Why" }, "q" => "skull")

    assert_equal({ "name" => "[FILTERED]", "email" => "[FILTERED]", "organisation" => "[FILTERED]", "purpose" => "[FILTERED]" }, logged["access_request"])
    assert_equal "skull", logged["q"]
  end

  test "an HTTPS-only host sends Strict-Transport-Security (force_ssl is the deployment's switch)" do
    assert_not Rails.configuration.force_ssl, "force_ssl is off in tests; production.rb turns it on with RAILS_FORCE_SSL=true"
    assert_includes File.read(Rails.root.join("config/environments/production.rb")), 'config.force_ssl = ENV["RAILS_FORCE_SSL"] == "true"'
  end
end
