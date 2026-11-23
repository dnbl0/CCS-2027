require "test_helper"
require Rails.root.join("lib/middleware/email_protection")

# CCS-233: an email address is never in a page's HTML as plain "name@domain", yet a browser shows and follows it as before (CCS-47).
class EmailProtectionTest < ActiveSupport::TestCase
  test "an address in text and in a mailto link is written with character references" do
    html = %(<p>Email <a href="mailto:mhm.info@unimelb.edu.au?subject=emu_mc-1">mhm.info@unimelb.edu.au</a></p>)
    protected_html = EmailProtection.protect(html)

    assert_no_match(/[A-Za-z0-9]@unimelb/, protected_html)
    assert_includes protected_html, "mailto:mhm.info&#64;unimelb&#46;edu&#46;au?subject=emu_mc-1"
    assert_equal "mhm.info@unimelb.edu.au", Nokogiri::HTML.fragment(protected_html).at_css("a").text # what a browser shows
    assert_equal "mailto:mhm.info@unimelb.edu.au?subject=emu_mc-1", Nokogiri::HTML.fragment(protected_html).at_css("a")["href"]
  end

  test "script and style blocks keep their characters" do
    html = %(<script type="application/ld+json">{"email":"a@b.org"}</script><p>c@d.org</p>)
    protected_html = EmailProtection.protect(html)

    assert_includes protected_html, %({"email":"a@b.org"})
    assert_includes protected_html, "c&#64;d&#46;org"
  end
end
