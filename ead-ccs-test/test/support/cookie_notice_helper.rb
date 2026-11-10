# Pretends the site has optional cookie categories (CookieNotice::OPTIONAL is empty today), for the length of the block.
module CookieNoticeHelper
  def with_optional_cookies(*categories)
    original = CookieNotice.method(:optional)
    CookieNotice.define_singleton_method(:optional) { categories }
    yield
  ensure
    CookieNotice.define_singleton_method(:optional, original)
  end

  def optional_category(key = :analytics, cookies: [ CookieNotice::Cookie.new(key: "analytics", name: "_ccs_analytics") ])
    CookieNotice::Category.new(key: key, cookies: cookies)
  end
end
