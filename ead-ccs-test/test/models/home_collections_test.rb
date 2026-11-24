require "test_helper"

# The home page's collections (HomeCollections): each opens its page here, or, where this site has no page or records for it, its page on
# the University's sites, never a search that finds nothing (docs/ia-audit-handover.md)
class HomeCollectionsTest < ActiveSupport::TestCase
  Helpers = Struct.new(:landings) do
    def landing_path_for(_kind, value) = landings[value]
    def search_action_path(query) = "/catalog?#{query.to_query}"
  end

  test "every collection but MONIAC has its University page, as the University's listing links it" do
    missing = (HomeCollections.museums + HomeCollections.art_collection).reject(&:url).map(&:title)
    assert_equal [ "MONIAC Economics Model Machine" ], missing
    assert (HomeCollections.museums + HomeCollections.art_collection).filter_map(&:url).all? { |url| url.match?(%r{\Ahttps?://[a-z.]+unimelb\.edu\.au/}) }
  end

  test "a collection with a page here opens it; one without opens its University page; with neither, its records in the search" do
    grainger, burnley = HomeCollections.museums.values_at(9, 2)
    moniac = HomeCollections.museums.find { |item| item.title.start_with?("MONIAC") }
    helpers = Helpers.new({ "Grainger Museum Collection" => "/browse/collections/grainger" })

    assert_equal "/browse/collections/grainger", HomeCollections.path(grainger, helpers)
    assert_equal burnley.url, HomeCollections.path(burnley, helpers)
    assert HomeCollections.external?(HomeCollections.path(burnley, helpers))
    assert_match %r{\A/catalog\?}, HomeCollections.path(moniac, helpers)
    assert_not HomeCollections.external?("/browse/collections/grainger")
  end
end
