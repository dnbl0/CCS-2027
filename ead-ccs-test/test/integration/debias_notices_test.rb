require "test_helper"
require_relative "../support/env_override"
require_relative "../support/debias_helper"

# De-bias notices on a record page and the page they link to. The term lists are test doubles with ordinary words from the records
# (the real list is the collections team's, not here); the explanations are made up.
class DebiasNoticesTest < ActionDispatch::IntegrationTest
  include DebiasHelper
  include EnvOverride

  OPEN_RECORD = "emu-406126" # title "Percy Grainger", open access
  ICIP_RECORD = "emu-108756" # title "Gay'wu (Bush string bag)", ICIP Rights: on request
  SENSITIVE_RECORD = "vernon-MHM2014.191" # restriction note "...Culturally sensitive images...", not displayed

  test "a record page with no terms listed has no notice and no mark" do
    needs_solr
    with_debias_terms do
      get "/catalog/#{OPEN_RECORD}"

      assert_response :success
      assert_select ".record-debias", 0
      assert_select "mark", 0
    end
  end

  test "the list that ships changes no record page" do
    needs_solr
    get "/catalog/#{OPEN_RECORD}"

    assert_response :success
    assert_select ".record-debias", 0
    assert_select "mark.debias-flag", 0
  end

  test "a flagged title gets a notice above the details and a mark in the Title row, and the text is not changed" do
    needs_solr
    with_debias_terms(debias_entry("grainger", severity: "caution", explanation: "Made-up reason.", alternative: "made-up alternative")) do
      get "/catalog/#{OPEN_RECORD}"

      assert_response :success
      assert_select "aside.record-debias h2", "This record contains language that may be offensive or outdated"
      assert_select "aside.record-debias a[href='/language-in-our-records']"
      assert_select "aside.record-debias a[href='#contact-collection-heading']"
      assert_select "#contact-collection-heading", 1
      assert_select ".record-main__details > aside.record-debias + section.record-details"
      assert_select ".record-debias__term", /Caution: Grainger/
      assert_select ".record-debias__explanation", "Made-up reason."

      assert_select "dd mark.debias-flag", 1
      mark = css_select("dd mark.debias-flag").first
      assert_equal "flagged term: Grainger", mark.text
      assert_equal "Percy Grainger", css_select("dt:contains('Title') + dd").first.text.squish.sub("flagged term: ", "")
      assert_equal "visually-hidden", mark.at_css("span")["class"]
    end
  end

  test "the page for the flagged record has the same layout: nothing outside the notice and the mark differs" do
    needs_solr
    get "/catalog/#{OPEN_RECORD}"
    plain = css_select(".record-details__row dd").map { |dd| dd.text.squish }
    with_debias_terms("grainger") do
      get "/catalog/#{OPEN_RECORD}"
      flagged = css_select(".record-details__row dd").map { |dd| dd.text.squish.gsub("flagged term: ", "") }

      assert_equal plain, flagged
    end
  end

  test "a record that is on request still shows the text it displays, so its notice shows; both notices are present" do
    needs_solr
    with_debias_terms("string") do
      get "/catalog/#{ICIP_RECORD}"

      assert_response :success
      assert_select "aside.record-cultural-protocols", 1
      assert_select "aside.record-debias", 1
      assert_select "aside.record-debias .record-debias__context", /Bush string bag/
    end
  end

  test "a term only in a field the page does not show gives no notice and appears nowhere on the page" do
    needs_solr
    with_debias_terms("Culturally") do
      get "/catalog/#{SENSITIVE_RECORD}"

      assert_response :success
      assert_select "aside.record-debias", 0
      assert_select "mark", 0
      assert_not_includes response.body, "Not for publishing"
    end
  end

  test "the notice is in the page's HTML, so it needs no script" do
    needs_solr
    with_debias_terms("grainger") do
      get "/catalog/#{OPEN_RECORD}"

      assert_select "aside.record-debias[data-controller]", 0
      assert_select "aside.record-debias script", 0
    end
  end

  test "the language page is public, has one h1, the placeholder notice, a breadcrumb and the contact routes" do
    get "/language-in-our-records"

    assert_response :success
    assert_select "h1", count: 1, text: "About the language in our records"
    assert_select "main#main-content"
    assert_select "#placeholder-notice", text: /Placeholder wording, not yet approved/
    assert_select "nav[aria-label*='readcrumb'] li, nav.breadcrumb li", text: /Language in our records/
    assert_select "a[href='/help#contact-us']"
    assert_select "a[href='/help#indigenous']"
    assert_select "h2", text: "Why we show the original wording"
    assert_select "meta[name=description][content*='offensive or outdated']"
  end

  test "the language page is indexable, canonical, in the sitemap and linked from the footer" do
    with_env("SEO_INDEXING" => "on") do
      get "/language-in-our-records"
      assert_not_includes response.headers["X-Robots-Tag"].to_s, "noindex"
      assert_select "link[rel=canonical][href$='/language-in-our-records']"
    end
    sitemap = Sitemap.new(base_url: "https://example.test", records: -> { [] })
    assert_includes sitemap.urls.map(&:first), "https://example.test/language-in-our-records"

    get "/help"
    assert_select ".site-footer__links a[href='/language-in-our-records']", text: "Language in our records"
  end

  test "the language page is not scanned: no mark or notice on it, whatever the list holds" do
    with_debias_terms("collections", "records") do
      get "/language-in-our-records"
      assert_select "mark", 0
      assert_select ".record-debias", 0
    end
  end
end
