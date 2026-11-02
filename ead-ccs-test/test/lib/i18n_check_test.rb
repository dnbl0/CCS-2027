require "test_helper"
require "open3"

# CCS-149: a literal t("nexus_ccs...") key that is in no locale file shows "Translation missing" text to a visitor (and a
# lazy .key in a view is easy to get wrong), so script/i18n_check.rb fails on one. The unused-key half runs in bin/ci only.
class I18nCheckTest < ActiveSupport::TestCase
  test "every literal key the app asks for under its own namespaces is in a locale file" do
    output, status = Open3.capture2e(RbConfig.ruby, Rails.root.join("script/i18n_check.rb").to_s, "--missing-only")

    assert status.success?, output
  end
end
