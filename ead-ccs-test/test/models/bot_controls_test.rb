require "test_helper"
require_relative "../support/env_override"

class BotControlsTest < ActiveSupport::TestCase
  include EnvOverride

  test "the AI training crawlers the story names are all on the list, from the one file" do
    %w[GPTBot ClaudeBot anthropic-ai CCBot Google-Extended PerplexityBot Bytespider Amazonbot Applebot-Extended cohere-ai Diffbot ImagesiftBot].each do |name|
      assert_includes BotControls.disallowed_crawlers, name
    end
    assert_equal YAML.load_file(Rails.root.join("config/ai_crawlers.yml")).fetch("training_and_scraping"), BotControls.disallowed_crawlers
  end

  test "Googlebot and Bingbot are never on a list" do
    all = BotControls::AGENTS.values.flatten.map(&:downcase)
    assert_not_includes all, "googlebot"
    assert_not_includes all, "bingbot"
    assert_not BotControls.blocked_user_agent?("Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)")
    assert_not BotControls.blocked_user_agent?("Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)")
  end

  test "a user agent is matched by a substring, whatever its case" do
    assert BotControls.blocked_user_agent?("Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; GPTBot/1.1; +https://openai.com/gptbot)")
    assert BotControls.blocked_user_agent?("claudebot")
    assert BotControls.blocked_user_agent?("Scrapy/2.11 (+https://scrapy.org)")
  end

  test "browsers, screen readers' browsers, curl, an empty agent and nil are not blocked" do
    [ "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", "curl/8.4.0",
      "python-requests/2.31", "", nil ].each { |agent| assert_not BotControls.blocked_user_agent?(agent), agent.inspect }
  end

  test "the AI search and answer agents are allowed unless BOT_BLOCK_AI_RETRIEVAL is on" do
    assert_not BotControls.blocked_user_agent?("ChatGPT-User/1.0")
    with_env("BOT_BLOCK_AI_RETRIEVAL" => "on") do
      assert BotControls.blocked_user_agent?("ChatGPT-User/1.0")
      assert_includes BotControls.disallowed_crawlers, "OAI-SearchBot"
    end
  end

  test "BOT_BLOCKED_USER_AGENTS adds to the list" do
    with_env("BOT_BLOCKED_USER_AGENTS" => "BadScraper, Other") { assert BotControls.blocked_user_agent?("xx badscraper/1") }
    assert_not BotControls.blocked_user_agent?("xx badscraper/1")
  end

  test "indexing is off outside production unless SEO_INDEXING=on" do
    assert_not BotControls.indexing?
    with_env("SEO_INDEXING" => "on") { assert BotControls.indexing? }
    with_env("SEO_INDEXING" => "ON") { assert BotControls.indexing? }
    with_env("SEO_INDEXING" => "yes") { assert_not BotControls.indexing? }
  end

  test "the canonical base URL can be fixed, and loses a trailing slash" do
    request = Struct.new(:base_url).new("http://internal:3000")
    assert_equal "http://internal:3000", BotControls.base_url(request)
    with_env("SEO_CANONICAL_BASE_URL" => "https://collections.example.edu.au/") { assert_equal "https://collections.example.edu.au", BotControls.base_url(request) }
  end
end
