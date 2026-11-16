require "test_helper"

class NexusCcs::CollectionDirectoryComponentTest < ViewComponent::TestCase
  test "lists every University collection once, split by whether its records are here" do
    render_inline(NexusCcs::CollectionDirectoryComponent.new)

    assert_equal UniversityCollections.all.size, page.all(".collection-directory__link").size
    assert_equal UniversityCollections.all.map(&:name).uniq.size, UniversityCollections.all.size
    assert_selector "h2", text: "All University collections"
    assert_selector "h3", text: "Search these collections here"
    assert_selector "h3", text: "Not in Collections Navigator yet"
  end

  test "collections with records are searched here and the rest link to their own site" do
    render_inline(NexusCcs::CollectionDirectoryComponent.new)

    assert_link "Grainger Museum Collection", href: %r{\A/catalog\?}
    assert_link "Tiegs Zoology Museum", href: "https://biosciences.unimelb.edu.au/engage/tiegs-museum"
    assert_no_link "Tiegs Zoology Museum", href: %r{\A/catalog}
  end

  test "every collection with records in the site navigation is in the list" do
    here = UniversityCollections.in_collections_navigator.map(&:name)
    NexusCcs::SiteNavigation.collections.each { |_label, value, _slug| assert_includes here, value }
  end

  test "every address is https or the one http site the University lists" do
    UniversityCollections.all.each { |entry| assert_match %r{\Ahttps?://}, entry.url }
  end
end
