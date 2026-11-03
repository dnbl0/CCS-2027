require "test_helper"

# Which requests count as a person looking at a record page
class CountsRecordViewsTest < ActiveSupport::TestCase
  CHROME = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
  SAFARI_PHONE = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

  def request_with(agent, method: "GET", path: "/catalog/emu-1", headers: {})
    env = Rack::MockRequest.env_for(path, { method: method }.merge(headers.transform_keys { |name| "HTTP_#{name.upcase.tr('-', '_')}" }))
    env["HTTP_USER_AGENT"] = agent if agent
    ActionDispatch::Request.new(env)
  end

  test "a browser asking for a page counts" do
    assert CountsRecordViews.human_looking?(request_with(CHROME))
    assert CountsRecordViews.human_looking?(request_with(SAFARI_PHONE))
  end

  test "crawlers, scrapers, monitors, link previews and HTTP libraries do not" do
    [ "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)", "Mozilla/5.0 AppleWebKit/537.36 (compatible; bingbot/2.0)",
      "GPTBot/1.1", "CCBot/2.0", "Bytespider", "curl/8.4.0", "python-requests/2.31", "Go-http-client/2.0", "Wget/1.21",
      "Mozilla/5.0 HeadlessChrome/120.0.0.0 Safari/537.36", "Slackbot-LinkExpanding 1.0", "facebookexternalhit/1.1", "UptimeRobot/2.0",
      "Mozilla/5.0 (compatible; AhrefsBot/7.0)", "Mozilla/5.0 Lighthouse", "node-fetch/1.0" ].each do |agent|
      assert_not CountsRecordViews.human_looking?(request_with(agent)), "#{agent} was counted"
    end
  end

  test "a user agent the bot controls block does not count, whatever it is called" do
    ENV["BOT_BLOCKED_USER_AGENTS"] = "AcmeScraper"
    assert_not CountsRecordViews.human_looking?(request_with("Mozilla/5.0 Chrome/130 AcmeScraper/1.0"))
    assert CountsRecordViews.human_looking?(request_with(CHROME))
  ensure
    ENV.delete("BOT_BLOCKED_USER_AGENTS")
  end

  test "no user agent, a prefetch, and anything but a page GET do not count" do
    assert_not CountsRecordViews.human_looking?(request_with(nil))
    assert_not CountsRecordViews.human_looking?(request_with(CHROME, headers: { "Purpose" => "prefetch" }))
    assert_not CountsRecordViews.human_looking?(request_with(CHROME, headers: { "Sec-Purpose" => "prefetch;prerender" }))
    assert_not CountsRecordViews.human_looking?(request_with(CHROME, method: "POST"))
    assert_not CountsRecordViews.human_looking?(request_with(CHROME, path: "/catalog/emu-1.json"))
  end
end
