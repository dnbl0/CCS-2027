require "test_helper"

class CollectionIntroTest < ViewComponent::TestCase
  def render_intro(params)
    with_controller_class(CatalogController) do
      with_request_url("/catalog") { render_inline(NexusCcs::CollectionIntroComponent.new(params: params.deep_stringify_keys)) }
    end
  end

  test "results filtered to one collection open with its name, its description and a link to visit it" do
    render_intro(f: { collection_ssim: [ "Medical History Museum" ] }, any_assets: "1")

    assert_selector "section.collection-intro[aria-labelledby='collection-intro-title'] h2#collection-intro-title", text: "Medical History Museum"
    assert_selector ".collection-intro__blurb", text: SitePages.collection("medical-history-museum")["blurb"]
    assert_link "Plan a visit", href: SitePages.collection("medical-history-museum")["visit_url"]
  end

  test "its named collections are listed behind a disclosure, each opening every record of that named collection in the collection" do
    render_intro(f: { collection_ssim: [ "Medical History Museum" ] })

    assert_selector "details.collection-intro__more:not([open]) summary", text: /\ANamed collections \(\d+\)\z/

    link = page.find_link("Royal Women's Hospital Collection", visible: :all)
    query = Rack::Utils.parse_nested_query(URI(link[:href]).query)
    assert_equal "1", query["any_assets"]
    assert_equal [ "Medical History Museum" ], query.dig("f", "collection_ssim")
    assert_equal [ "Royal Women's Hospital Collection" ], query.dig("f", "named_collection_ssim")
  end

  test "a collection with no named collections shows no list" do
    render_intro(f: { collection_ssim: [ "Grainger Museum Collection" ] })

    assert_selector "h2", text: "Grainger Museum Collection"
    assert_no_selector ".collection-intro__named"
  end

  test "nothing for a search across collections, two collections, or a collection the site does not describe" do
    [ {}, { q: "skull" }, { f: { collection_ssim: [ "Medical History Museum", "University Art Collection" ] } },
      { f: { collection_ssim: [ "University of Melbourne" ] } }, { f: { collection_ssim: "Medical History Museum" } } ].each do |params|
      render_intro(params)
      assert_empty page.all(".collection-intro"), params.inspect
    end
  end
end
