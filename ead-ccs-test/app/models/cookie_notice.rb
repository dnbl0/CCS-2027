# frozen_string_literal: true

# The cookie notice (CCS-471): which cookies the site sets, which of them are essential, and what a visitor chose.
#
# ESSENTIAL is the honest list of every cookie the app sets today. A test (test/integration/cookie_notice_test.rb) fails when a
# page sets a cookie that is not named here or in OPTIONAL, so this list cannot drift from the app. The same list feeds the notice
# (NexusCcs::CookieNoticeComponent) and the Cookies section of /privacy.
#
# OPTIONAL is empty: the site sets no analytics, advertising or other non-essential cookie, so the notice offers no choice and
# says so (inventing one would be untrue). To add one later, add a Category with the cookies it would set and wording under
# nexus_ccs.cookie_notice.optional.<key>; the notice then shows equal "Accept" and "Decline" buttons, nothing is ticked or set
# until the visitor accepts, and the code that would set the cookie asks CookieNotice.optional_allowed?(cookies) first. Raising
# VERSION asks every visitor again.
#
# The visitor's answer is kept in one first-party cookie (COOKIE): "<VERSION>.<choice>". It is itself essential (without it the
# notice would come back on every page) and holds no identifier. The wording is PLACEHOLDER wording until the University approves it.
module CookieNotice
  COOKIE = :ccs_cookie_notice
  VERSION = "1"
  LIFETIME = 180.days

  # acknowledged: read it (no optional cookies exist); accepted / declined: the answer when optional cookies exist
  CHOICES = %w[acknowledged accepted declined].freeze

  Cookie = Struct.new(:key, :name, keyword_init: true)
  Category = Struct.new(:key, :cookies, keyword_init: true)

  ESSENTIAL = [
    Cookie.new(key: "session", name: "_ccs_session"),
    Cookie.new(key: "country", name: "country_acknowledged"),
    Cookie.new(key: "notice", name: COOKIE.to_s)
  ].freeze

  OPTIONAL = [].freeze

  module_function

  def essential = ESSENTIAL

  def optional = OPTIONAL

  def choosable? = optional.any?

  # What the notice may record: one acknowledgement when there is nothing to choose, otherwise accept or decline
  def accepted_choices = choosable? ? %w[accepted declined] : %w[acknowledged]

  def value(choice) = "#{VERSION}.#{choice}"

  # The saved choice, or nil when there is none, it is from an earlier version of the notice, or it is not a known choice
  def choice(cookies)
    version, choice = cookies[COOKIE].to_s.split(".", 2)
    choice if version == VERSION && CHOICES.include?(choice)
  end

  def pending?(cookies) = choice(cookies).nil?

  # The only question code that sets an optional cookie may ask: true only after an explicit "accepted"
  def optional_allowed?(cookies) = choice(cookies) == "accepted"
end
