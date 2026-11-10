require "test_helper"
require "view_component/test_helpers"

class BannerTest < ActiveSupport::TestCase
  # The banner and the home page hero share these rules
  SCOPE = /:is\(\.search-banner, \.ccs-hero__search, \.sticky-search\)/

  test "the banner copy is the default description until there is a search" do
    assert_match(/Explore artworks, objects, manuscripts/, NexusCcs::SearchBannerComponent::DESCRIPTION)
    assert_equal "Search the collections", NexusCcs::SearchBannerComponent::TITLE
  end

  test "the banner styles follow the static page: 48px bar, 720px, visible Advanced search link" do
    css = Rails.root.join("app/assets/stylesheets/components/search_banner.css").read

    assert_match(/#{SCOPE} \.input-group \{[^}]*height: 3rem;/m, css)
    assert_match(/\.search-banner__form \{[^}]*max-width: 45rem;/m, css)
    assert_match(/#{SCOPE} \.advanced_search \{[^}]*display: inline-flex;/m, css)
    assert_no_match(/\.advanced_search \{[^}]*clip: rect/m, css)
    assert_match(/\.search-banner__desc \{[^}]*line-height: 1\.75rem;/m, css)
  end
end
