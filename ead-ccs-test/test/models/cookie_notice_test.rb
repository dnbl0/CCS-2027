require "test_helper"
require_relative "../support/cookie_notice_helper"

class CookieNoticeTest < ActiveSupport::TestCase
  include CookieNoticeHelper

  # The jar a controller sees: a Hash is enough for what CookieNotice reads
  def jar(value = nil) = value ? { CookieNotice::COOKIE => value } : {}

  test "a visitor with no cookie has not been told" do
    assert CookieNotice.pending?(jar)
    assert_nil CookieNotice.choice(jar)
  end

  test "the choice that was saved is read back, and an unknown or old one asks again" do
    CookieNotice::CHOICES.each { |choice| assert_equal choice, CookieNotice.choice(jar(CookieNotice.value(choice))) }
    assert CookieNotice.pending?(jar("0.acknowledged")), "an earlier version of the notice is shown again"
    assert CookieNotice.pending?(jar("#{CookieNotice::VERSION}.shrug"))
    assert CookieNotice.pending?(jar("garbage"))
  end

  test "the site sets no optional cookie today, so there is no choice to offer" do
    assert_empty CookieNotice.optional
    assert_not CookieNotice.choosable?
    assert_equal %w[acknowledged], CookieNotice.accepted_choices
  end

  test "once an optional category exists the visitor chooses between accepting and declining, and acknowledging is no longer enough" do
    with_optional_cookies(optional_category) do
      assert CookieNotice.choosable?
      assert_equal %w[accepted declined], CookieNotice.accepted_choices
    end
  end

  test "optional cookies are allowed only after the visitor accepted them: no cookie, declined or acknowledged all mean no" do
    assert_not CookieNotice.optional_allowed?(jar)
    assert_not CookieNotice.optional_allowed?(jar(CookieNotice.value("declined")))
    assert_not CookieNotice.optional_allowed?(jar(CookieNotice.value("acknowledged")))
    assert CookieNotice.optional_allowed?(jar(CookieNotice.value("accepted")))
  end

  test "every essential cookie the notice lists has a name and wording for what it is for and how long it lasts" do
    assert_includes CookieNotice.essential.map(&:name), "_ccs_session"
    assert_includes CookieNotice.essential.map(&:name), "country_acknowledged"
    assert_includes CookieNotice.essential.map(&:name), CookieNotice::COOKIE.to_s
    CookieNotice.essential.each do |cookie|
      assert I18n.exists?("nexus_ccs.cookie_notice.cookies.#{cookie.key}.purpose"), cookie.key
      assert I18n.exists?("nexus_ccs.cookie_notice.cookies.#{cookie.key}.lifetime"), cookie.key
    end
  end
end
