require "test_helper"
require_relative "../support/env_override"

# /robots.txt, /sitemap.xml and /llms.txt (CCS-128, CCS-127)
class SeoFilesTest < ActionDispatch::IntegrationTest
  include EnvOverride

  ON = { "SEO_INDEXING" => "on" }.freeze

  def groups(text)
    text.split(/\n\n+/).map { |group| group.lines.map(&:strip).reject { |line| line.start_with?("#") || line.empty? } }
  end

  test "robots.txt names each AI training crawler once in a group that disallows everything" do
    with_env(ON) { get "/robots.txt" }

    assert_response :success
    assert_equal "text/plain", response.media_type
    ai = groups(response.body).find { |group| group.include?("User-agent: GPTBot") }
    assert_includes ai, "Disallow: /"
    %w[GPTBot ClaudeBot anthropic-ai CCBot Google-Extended PerplexityBot Bytespider Amazonbot Applebot-Extended cohere-ai Diffbot ImagesiftBot].each do |name|
      assert_equal 1, response.body.scan("User-agent: #{name}\n").size, name
      assert_includes ai, "User-agent: #{name}"
    end
  end

  test "robots.txt leaves Googlebot and Bingbot under the * group, which keeps personal pages and asset files out and the sitemap in" do
    with_env(ON) { get "/robots.txt" }

    assert_no_match(/Googlebot|Bingbot/i, response.body)
    star = groups(response.body).find { |group| group.first == "User-agent: *" }
    assert_not_includes star, "Disallow: /"
    %w[/bookmarks /saved_searches /search_history /lists /access_requests /downloads /catalog/facet/ /stock/ /digital-assets/ /catalog/*/metadata].each do |path|
      assert_includes star, "Disallow: #{path}", path
    end
    assert_includes response.body, "Sitemap: http://www.example.com/sitemap.xml"
  end

  test "robots.txt closes the whole site when indexing is off, and the sitemap is a 404" do
    get "/robots.txt"
    assert_match(/User-agent: \*\nDisallow: \/\n/, response.body)
    assert_no_match(/GPTBot/, response.body)

    get "/sitemap.xml"
    assert_response :not_found
  end

  test "BOT_CONTROLS=off leaves the AI crawlers out of robots.txt and BOT_BLOCK_AI_RETRIEVAL=on adds the answer agents" do
    with_env(ON.merge("BOT_CONTROLS" => "off")) { get "/robots.txt" }
    assert_no_match(/GPTBot/, response.body)

    with_env(ON.merge("BOT_BLOCK_AI_RETRIEVAL" => "on")) { get "/robots.txt" }
    assert_match(/User-agent: OAI-SearchBot/, response.body)
  end

  test "robots.txt and the sitemaps carry no session cookie and can be cached" do
    with_env(ON) { get "/robots.txt" }

    assert_nil response.headers["Set-Cookie"]
    assert_match(/public/, response.headers["Cache-Control"])
  end

  test "the canonical base URL setting is used in the Sitemap line" do
    with_env(ON.merge("SEO_CANONICAL_BASE_URL" => "https://ccs.example.edu.au")) { get "/robots.txt" }

    assert_includes response.body, "Sitemap: https://ccs.example.edu.au/sitemap.xml"
  end

  test "the sitemap is an index of pages, each with at most 10,000 URLs, from the real index, and has no asset address" do
    needs_solr
    with_env(ON) { get "/sitemap.xml" }

    assert_response :success
    assert_equal "application/xml", response.media_type
    children = Nokogiri::XML(response.body).css("sitemap loc").map(&:text)
    assert_operator children.size, :>=, 1
    assert_equal "http://www.example.com/sitemaps/1.xml", children.first

    with_env(ON) { get "/sitemaps/1.xml" }
    urls = Nokogiri::XML(response.body).css("url loc").map(&:text)
    assert_operator urls.size, :<=, 10_000
    assert_includes urls, "http://www.example.com/"
    assert(urls.any? { |url| url.start_with?("http://www.example.com/catalog/") })
    assert_not_includes response.body, "digital-assets"

    with_env(ON) { get "/sitemaps/#{children.size + 1}.xml" }
    assert_response :not_found
  end

  test "the sitemap leaves out withheld and sensitive records of the real index" do
    needs_solr
    with_env(ON) { get "/sitemap.xml" }
    ids = Nokogiri::XML(response.body).css("sitemap loc").size.times.flat_map do |index|
      with_env(ON) { get "/sitemaps/#{index + 1}.xml" }
      Nokogiri::XML(response.body).css("url loc").map { |loc| URI.decode_www_form_component(loc.text.split("/catalog/").last) }
    end
    withheld = Blacklight.default_index.connection.get("select", params: { q: "restrictions_tsi:sensitive OR licence_type_ssim:(\"ICIP Rights\" OR \"Restricted Access\")", rows: 100, fl: "id" })["response"]["docs"].pluck("id")

    assert_not_empty withheld
    assert_empty ids & withheld
  end

  test "llms.txt is off until its wording is approved, then states the placeholder rights position" do
    with_env(ON) { get "/llms.txt" }
    assert_response :not_found

    with_env(ON.merge("SEO_LLMS_TXT" => "on")) { get "/llms.txt" }
    assert_response :success
    assert_match(/\A# Collections Navigator/, response.body)
    assert_match(/PLACEHOLDER WORDING/, response.body)
    assert_includes response.body, "http://www.example.com/sitemap.xml"
  end
end
