require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"
require_relative "../../support/cookie_notice_helper"

class CookieNoticeComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions
  include CookieNoticeHelper

  def page = Capybara::Node::Simple.new(rendered_content)

  test "with no optional cookie it says so, offers one acknowledgement and no pretend choice" do
    render_inline(NexusCcs::CookieNoticeComponent.new)

    assert_selector "section[aria-labelledby=cookie-notice-title] h2#cookie-notice-title", text: "Cookies on this site"
    assert_text "only the cookies it needs"
    assert_text "no advertising or analytics cookies"
    assert_selector "form[action='/cookie_notice'][method=post] button[name=choice][value=acknowledged]", count: 1
    assert_selector "button", count: 1
    assert_no_text "Decline"
    assert_selector "a[href='/privacy#cookies']"
  end

  test "it is marked as placeholder wording, in the markup and in words" do
    render_inline(NexusCcs::CookieNoticeComponent.new)

    assert_selector "section[data-placeholder-wording]"
    assert_text "Placeholder"
  end

  test "it is not a dialog: no role dialog, no modal, nothing focused for the visitor" do
    render_inline(NexusCcs::CookieNoticeComponent.new)

    assert_no_selector "[role=dialog], [role=alertdialog], dialog, [aria-modal], [autofocus]"
  end

  test "with an optional category accepting and declining are two buttons of one kind, declining first in the markup" do
    I18n.backend.store_translations(:en, nexus_ccs: { cookie_notice: { optional: { analytics: { name: "Analytics", purpose: "Counts visits." } } } })
    with_optional_cookies(optional_category) do
      render_inline(NexusCcs::CookieNoticeComponent.new)
    end

    declined = page.find("button[value=declined]")
    accepted = page.find("button[value=accepted]")
    assert_equal declined[:class], accepted[:class], "equal prominence"
    assert_operator rendered_content.index('value="declined"'), :<, rendered_content.index('value="accepted"')
    assert_no_selector "button[value=acknowledged]"
    assert_text "Analytics"
    assert_no_selector "input[type=checkbox][checked]" # nothing is pre-ticked
  end
end
