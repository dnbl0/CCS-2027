require "test_helper"
require_relative "../support/env_override"

# The accessibility statement, the privacy notice and Delete my data (CCS-148).
class CompliancePagesTest < ActionDispatch::IntegrationTest
  include EnvOverride

  test "the accessibility statement and privacy notice are public pages in the page layout, marked as placeholder wording" do
    %w[/accessibility /privacy].each do |path|
      get path

      assert_response :success, path
      assert_select "h1", count: 1
      assert_select "main#main-content"
      assert_select "#placeholder-notice", text: /Placeholder wording, not yet approved/
      assert_select "a[href='/help#contact-us']"
    end
  end

  test "both pages are indexable and listed in the sitemap" do
    with_env("SEO_INDEXING" => "on") do
      %w[/accessibility /privacy].each do |path|
        get path
        assert_not_includes response.headers["X-Robots-Tag"], "noindex", path
      end
    end
    sitemap = Sitemap.new(base_url: "https://example.test", records: -> { [] })
    assert_includes sitemap.urls.map(&:first), "https://example.test/accessibility"
    assert_includes sitemap.urls.map(&:first), "https://example.test/privacy"
  end

  test "the footer keeps the University's own pages and adds this site's two statements" do
    get "/help"

    assert_select ".site-footer__legal a[href='https://www.unimelb.edu.au/accessibility']", text: "Accessibility"
    assert_select ".site-footer__legal a[href='https://about.unimelb.edu.au/strategy/governance/compliance-obligations/privacy']", text: "Privacy"
    assert_select ".site-footer__legal a[href='/accessibility']"
    assert_select ".site-footer__legal a[href='/privacy']"
  end

  test "the privacy notice links to Delete my data only while saved records are on" do
    get "/privacy"
    assert_select "#your-choices a[href='/my_data']"

    was = Rails.configuration.x.saved_records
    Rails.configuration.x.saved_records = false
    get "/privacy"
    assert_select "#your-choices a[href='/my_data']", count: 0
  ensure
    Rails.configuration.x.saved_records = was unless was.nil?
  end

  test "the page descriptions are their own" do
    assert_equal I18n.t("seo.description.accessibility"), PageMeta.new(controller: "pages", action: "accessibility", path: "/accessibility", params: {}, base_url: "https://x.test", title: "t").description
    assert_equal I18n.t("seo.description.privacy"), PageMeta.new(controller: "pages", action: "privacy", path: "/privacy", params: {}, base_url: "https://x.test", title: "t").description
  end
end
