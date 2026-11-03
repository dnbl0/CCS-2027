require "test_helper"

class EmbedPolicyTest < ActiveSupport::TestCase
  test "any site may frame an embed unless the setting names some" do
    [ nil, "", "  ", "*", "https://a.example.org, *" ].each { |setting| assert_equal [ "*" ], EmbedPolicy.ancestors(setting), setting.inspect }
  end

  test "a list of origins keeps the site itself and those origins, separated by spaces or commas" do
    ancestors = EmbedPolicy.ancestors("https://museum.example.org, https://*.example.edu http://localhost:3000")

    assert_equal [ "'self'", "https://museum.example.org", "https://*.example.edu", "http://localhost:3000" ], ancestors
  end

  test "an entry that is not a plain origin is ignored, so a typo cannot widen the policy" do
    ancestors = EmbedPolicy.ancestors("https://ok.example.org data: 'none' https://x.example.org/path javascript:alert(1) ; https://bad.example.org;default-src")

    assert_equal [ "'self'", "https://ok.example.org" ], ancestors
  end

  test "the policy of an embed page loads nothing but the site's own images and styles, and sends no form" do
    policy = EmbedPolicy.content_security_policy("https://a.example.org")

    assert_includes policy, "default-src 'none'"
    assert_includes policy, "img-src 'self' data:"
    assert_includes policy, "form-action 'none'"
    assert_includes policy, "frame-ancestors 'self' https://a.example.org"
    assert_not_includes policy, "script-src"
  end
end
