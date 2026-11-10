require "test_helper"
require "capybara/cuprite"

# System tests drive a real headless Chrome over the DevTools protocol (Cuprite). Set BROWSER_PATH to use a Chrome or
# Chromium that is not on the PATH. They search the Solr core at SOLR_URL, which must hold the indexed records
# (see docs/solr-dev.md).
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Capybara waits this long for a page to change before an assertion fails. The 2 s default is too short when the machine
  # or the CI runner is busy: a Turbo page change (view switch, a link to /bookmarks) has failed assertions that pass on rerun.
  Capybara.default_max_wait_time = 6

  driven_by :cuprite, screen_size: [ 1440, 900 ], options: { browser_options: { "no-sandbox" => nil }, process_timeout: 30, timeout: 15 }

  # The cookie notice (CCS-471) is at the top of every page for a visitor who has not answered it; most tests are not about it, so
  # each starts as a visitor who has. test/system/cookie_notice_test.rb starts without the cookie.
  setup { page.driver.set_cookie(CookieNotice::COOKIE.to_s, CookieNotice.value("acknowledged")) }

  # axe-core comes from the static site's dependencies (npm install at the repository root)
  AXE = Rails.root.join("../node_modules/axe-core/axe.min.js")
  AXE_TAGS = %w[wcag2a wcag2aa wcag21a wcag21aa].freeze
  WCAG22_TAGS = %w[wcag22aa best-practice].freeze

  # Fails with each violation (rule, impact, elements) when axe finds any on the current page. `except` lists rule ids
  # that are known and tracked elsewhere; `tags` are the axe rule sets (AXE_TAGS + WCAG22_TAGS also checks WCAG 2.2 AA).
  def assert_accessible(except: [], tags: AXE_TAGS)
    flunk "axe-core is not installed: run npm install at the repository root" unless AXE.exist?

    page.execute_script(AXE.read) unless page.evaluate_script("typeof axe") == "object"
    violations = page.evaluate_async_script(<<~JS, tags)
      var tags = arguments[0], done = arguments[arguments.length - 1];
      axe.run(document, { runOnly: { type: "tag", values: tags } }).then(function (results) {
        done(results.violations.map(function (v) {
          return { id: v.id, impact: v.impact, help: v.help, targets: v.nodes.slice(0, 3).map(function (n) { return n.target.join(" ") }) };
        }));
      });
    JS
    violations = violations.reject { |violation| except.include?(violation["id"]) }

    assert_empty violations, violations.map { |v| "#{v["id"]} (#{v["impact"]}): #{v["help"]} at #{v["targets"].join(" | ")}" }.join("\n")
  end
end
