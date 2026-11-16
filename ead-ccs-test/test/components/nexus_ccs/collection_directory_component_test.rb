require "test_helper"

class NexusCcs::CollectionDirectoryComponentTest < ViewComponent::TestCase
  setup { @cache = Rails.cache }

  NONE = {}.freeze
  TIEGS = { "Tiegs Zoology Museum" => 120 }.freeze

  test "lists every University collection once, split by whether it can be searched here" do
    render_inline(NexusCcs::CollectionDirectoryComponent.new(counts: NONE))

    assert_equal UniversityCollections.all(NONE).size, page.all(".collection-directory__link").size
    assert_equal UniversityCollections.all(NONE).map(&:name).uniq.size, UniversityCollections.all(NONE).size
    assert_selector "h2", text: "All University collections"
    assert_selector "h3", text: "Search these collections here"
    assert_selector "h3", text: "Not in Collections Navigator yet"
  end

  test "collections with a landing page are searched here and the rest link to their own site" do
    render_inline(NexusCcs::CollectionDirectoryComponent.new(counts: NONE))

    assert_link "Grainger Museum Collection", href: %r{\A/catalog\?}
    assert_link "Tiegs Zoology Museum", href: "https://biosciences.unimelb.edu.au/engage/tiegs-museum"
  end

  test "a collection whose records arrive in the index becomes searchable with no code change" do
    render_inline(NexusCcs::CollectionDirectoryComponent.new(counts: TIEGS))

    link = page.find_link("Tiegs Zoology Museum")
    assert_match %r{\A/catalog\?}, link[:href]
    assert_includes CGI.unescape(link[:href]), "f[collection_ssim][]=Tiegs Zoology Museum"
    assert_includes CGI.unescape(link[:href]), "any_assets=1", "a collection without images still shows all its records"
  end

  test "every collection with a landing page is in the list" do
    here = UniversityCollections.in_collections_navigator(NONE).map(&:facet_value)
    NexusCcs::SiteNavigation.collections.each { |_label, value, _slug| assert_includes here, value }
  end

  test "an outage leaves the configured collections searchable, and is not asked again at once" do
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    calls = 0
    UniversityCollections.singleton_class.send(:alias_method, :real_fetch, :fetch_counts)
    UniversityCollections.singleton_class.send(:define_method, :fetch_counts) { calls += 1; nil }
    2.times { assert_equal({}, UniversityCollections.counts) }
    assert_equal 1, calls
    assert_includes UniversityCollections.in_collections_navigator({}).map(&:name), "Grainger Museum Collection"
  ensure
    UniversityCollections.singleton_class.send(:alias_method, :fetch_counts, :real_fetch)
    Rails.cache = @cache
  end

  test "every address is http or https" do
    UniversityCollections.all(NONE).each { |entry| assert_match %r{\Ahttps?://}, entry.url }
  end
end
