require "test_helper"
require_relative "../support/env_override"

# The bot controls (CCS-127): the 403 for listed user agents on asset files and the zip/CSV endpoints, and the per-IP rate limit.
class BotGuardTest < ActionDispatch::IntegrationTest
  include EnvOverride

  ASSET = "/digital-assets/thumbs/1973_0755-1_pf.jpg".freeze
  BOT = { "User-Agent" => "Mozilla/5.0 (compatible; GPTBot/1.1; +https://openai.com/gptbot)" }.freeze
  BROWSER = { "User-Agent" => "Mozilla/5.0 (X11; Linux x86_64) Firefox/126.0" }.freeze

  setup { BotGuard.store.clear }

  test "a listed user agent gets a 403 on an asset file; a browser, Googlebot and no user agent do not" do
    skip "no asset file in this checkout" unless Rails.public_path.join(ASSET.delete_prefix("/")).exist?

    get ASSET, headers: BOT
    assert_response :forbidden
    assert_equal "noindex", response.headers["X-Robots-Tag"]

    get ASSET, headers: BROWSER
    assert_response :success
    assert_equal "noindex, noai, noimageai", response.headers["X-Robots-Tag"]

    get ASSET, headers: { "User-Agent" => "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" }
    assert_response :success
  end

  test "a listed user agent gets a 403 on the CSV export and the zip endpoints, and a scraper toolkit too" do
    get "/catalog/emu-9044/metadata", headers: BOT
    assert_response :forbidden

    post "/downloads", headers: { "User-Agent" => "Scrapy/2.11" }
    assert_response :forbidden

    post "/downloads/review", headers: BOT
    assert_response :forbidden
  end

  test "a listed user agent may still read the pages (robots.txt is what asks it not to)" do
    get "/help", headers: BOT
    assert_response :success
  end

  test "BOT_CONTROLS=off lifts the 403" do
    with_env("BOT_CONTROLS" => "off") do
      get "/catalog/emu-9044/metadata", headers: BOT
      assert_not_equal 403, response.status
    end
  end

  test "BOT_BLOCKED_USER_AGENTS adds an agent" do
    with_env("BOT_BLOCKED_USER_AGENTS" => "MyScraper") do
      get "/catalog/emu-9044/metadata", headers: { "User-Agent" => "MyScraper/1.0" }
      assert_response :forbidden
    end
  end

  test "past its limit an IP gets 429 with Retry-After; before it, and with a person's pace, requests are untouched" do
    with_env("RATE_LIMIT" => "on", "RATE_LIMIT_RECORD_PER_MINUTE" => "5") do
      5.times do
        get "/stock/emu-9044", headers: BROWSER
        assert_not_equal 429, response.status
      end
      get "/stock/emu-9044", headers: BROWSER

      assert_response :too_many_requests
      assert response.headers["Retry-After"].to_i.between?(1, 60), response.headers["Retry-After"]
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_match(/Too many requests/, response.body)
    end
  end

  test "the limit is per IP address and per kind of request" do
    with_env("RATE_LIMIT" => "on", "RATE_LIMIT_RECORD_PER_MINUTE" => "2", "RATE_LIMIT_SEARCH_PER_MINUTE" => "2") do
      3.times { get "/catalog/emu-9044", headers: BROWSER }
      assert_response :too_many_requests

      get "/catalog/advanced", headers: BROWSER # not a record: its own page, not counted
      assert_response :success

      get "/stock/emu-9044", headers: BROWSER.merge("REMOTE_ADDR" => "203.0.113.9")
      assert_not_equal 429, response.status
    end
  end

  test "the download endpoints have their own, smaller, limit" do
    with_env("RATE_LIMIT" => "on", "RATE_LIMIT_DOWNLOAD_PER_MINUTE" => "2") do
      3.times { post "/downloads/review", headers: BROWSER }
      assert_response :too_many_requests
    end
  end

  test "the default limits are generous for a person: a hundred searches in a minute are not stopped" do
    needs_solr
    with_env("RATE_LIMIT" => "on") do
      100.times { get "/catalog.json", params: { q: "a" }, headers: BROWSER }
      assert_not_equal 429, response.status
    end
  end

  test "RATE_LIMIT_ALLOW_IPS exempts an address, and RATE_LIMIT=off stops the limit" do
    with_env("RATE_LIMIT" => "on", "RATE_LIMIT_RECORD_PER_MINUTE" => "1", "RATE_LIMIT_ALLOW_IPS" => "127.0.0.1") do
      3.times { get "/stock/emu-9044", headers: BROWSER }
      assert_not_equal 429, response.status
    end
    with_env("RATE_LIMIT" => "off", "RATE_LIMIT_RECORD_PER_MINUTE" => "1") do
      3.times { get "/stock/emu-9044", headers: BROWSER }
      assert_not_equal 429, response.status
    end
  end

  test "the memory store counts a window and starts again in the next" do
    store = BotGuard::MemoryStore.new

    assert_equal 1, store.increment("k", expires_in: 60, now: 1000)
    assert_equal 2, store.increment("k", expires_in: 60, now: 1030)
    assert_equal 1, store.increment("k", expires_in: 60, now: 1061)
    assert_equal 1, store.increment("other", expires_in: 60, now: 1061)
  end

  test "RATE_LIMIT_STORE=cache counts in Rails.cache" do
    with_env("RATE_LIMIT" => "on", "RATE_LIMIT_STORE" => "cache", "RATE_LIMIT_RECORD_PER_MINUTE" => "1") do
      original = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      2.times { get "/stock/emu-9044", headers: BROWSER }
      assert_response :too_many_requests
    ensure
      Rails.cache = original
    end
  end
end
