require "test_helper"

class ZeroResultsTest < ActiveSupport::TestCase
  test "clearing the filters keeps the search and drops every filter, the default one included" do
    params = { "q" => "skull", "search_field" => "all_fields", "view" => "list", "page" => "3",
               "f" => { "has_digital_asset" => [ "with" ], "collection_ssim" => [ "Grainger Museum" ] },
               "f_inclusive" => { "format" => [ "Image" ] }, "range" => { "date_range" => { "begin" => "1900" } } }

    assert_equal({ "q" => "skull", "search_field" => "all_fields", "view" => "list", "any_assets" => "1" },
                 ZeroResults.without_filters(params))
  end

  test "an Advanced search keeps its clauses when the filters are cleared" do
    params = { "op" => "must", "clause" => { "0" => { "field" => "title", "query" => "skull" } }, "f" => { "has_digital_asset" => [ "with" ] } }

    assert_equal params.except("f").merge("any_assets" => "1"), ZeroResults.without_filters(params)
  end

  test "filtered? is true for any filter, false for a search alone" do
    assert ZeroResults.filtered?({ "q" => "skull", "f" => { "has_digital_asset" => [ "with" ] } })
    assert ZeroResults.filtered?({ "q" => "skull", "range" => { "date_range" => { "begin" => "1900" } } })
    assert_not ZeroResults.filtered?({ "q" => "skull", "any_assets" => "1" })
  end

  test "only_default_filter? is true when With a digital asset is the one filter" do
    assert ZeroResults.only_default_filter?({ "q" => "skull", "f" => { "has_digital_asset" => [ "with" ] } })
    assert_not ZeroResults.only_default_filter?({ "f" => { "has_digital_asset" => [ "with" ], "collection_ssim" => [ "Grainger Museum" ] } })
    assert_not ZeroResults.only_default_filter?({ "f" => { "has_digital_asset" => [ "without" ] } })
  end

  # --- related categories (what an empty page offers instead) ---

  FACETS = { "collection_ssim" => [ "Grainger Museum Collection", 40, "Archives", 3 ], "object_type_ssim" => [ "photograph", 25 ],
             "creator_ssim" => [ "Grainger, Percy Aldridge", 12 ] }.freeze

  test "from the same search without its filters: the top value of each kind, as that search with the one filter" do
    related = ZeroResults.related_from_facets(FACETS, { "q" => "skull", "search_field" => "all_fields", "f" => { "collection_ssim" => [ "Medical History" ] } })

    assert_equal [ "Grainger Museum Collection", "photograph", "Grainger, Percy Aldridge" ], related.map(&:value)
    assert_equal [ "Collection", "Object type", "Creator" ], related.map(&:kind)
    assert_equal({ "q" => "skull", "search_field" => "all_fields", "any_assets" => "1", "f" => { "collection_ssim" => [ "Grainger Museum Collection" ] } },
                 related.first.query)
  end

  test "no facets give no categories" do
    assert_equal [], ZeroResults.related_from_facets({}, { "q" => "x" })
    assert_equal [], ZeroResults.related_from_facets(nil, { "q" => "x" })
  end

  test "from the words when nothing matches them: the categories whose names contain the longest word, never titles" do
    found = [ CategorisedSuggestions::Suggestion.new(value: "Skulls", kind: "Object type", query: { f: { "object_type_ssim" => [ "Skulls" ] } }),
              CategorisedSuggestions::Suggestion.new(value: "Skull of a cat", kind: "Title", query: { q: "Skull of a cat" }) ]
    asked = []
    finder = ->(text) { asked << text; found }
    related = ZeroResults.related_from_words("a skull ox", finder: finder)

    assert_equal [ "skull" ], asked
    assert_equal [ "Skulls" ], related.map(&:value)
    assert_equal [], ZeroResults.related_from_words("a b", finder: finder)
    assert_equal [ "skull" ], asked
  end
end
