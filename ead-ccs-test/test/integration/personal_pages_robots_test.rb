require "test_helper"
require_relative "../support/env_override"

# Account-like and personal pages are never indexed (CCS-128), whatever they answer: the header is set by BotGuard on every response.
class PersonalPagesRobotsTest < ActionDispatch::IntegrationTest
  include EnvOverride

  GET_PATHS = %w[
    /bookmarks /bookmarks/citations /saved_searches /search_history /lists /lists/1 /lists/1/citations /access_requests/new
    /access_requests/1 /catalog/emu-9044/metadata /catalog/emu-9044/citation /catalog/facet/collection_ssim /catalog/range_limit
    /downloads /404
  ].freeze

  test "every personal page, whatever its status, says noindex, nofollow in X-Robots-Tag, with indexing on" do
    needs_solr
    with_env("SEO_INDEXING" => "on") do
      GET_PATHS.each do |path|
        get path
        assert_match(/\Anoindex, nofollow/, response.headers["X-Robots-Tag"].to_s, "GET #{path} (#{response.status})")
      end
      [ "/downloads", "/downloads/review", "/catalog/emu-9044/sensitivity" ].each do |path|
        post path
        assert_match(/\Anoindex, nofollow/, response.headers["X-Robots-Tag"].to_s, "POST #{path} (#{response.status})")
      end
    end
  end

  test "the page that is a real personal page also says so in its head" do
    with_env("SEO_INDEXING" => "on") do
      get "/search_history"
      assert_equal "noindex, nofollow, noai, noimageai", css_select("meta[name=robots]").first["content"]
      assert_empty css_select("link[rel=canonical]")
    end
  end

  test "an error page is never indexed, and is given no canonical or social tags" do
    with_env("SEO_INDEXING" => "on") { get "/no-such-page" }

    assert_response :not_found
    assert_match(/\Anoindex, nofollow/, response.headers["X-Robots-Tag"])
    assert_empty css_select("meta[property='og:title']")
  end
end
