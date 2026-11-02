require "test_helper"

class SavedSearchTest < ActiveSupport::TestCase
  test "a name is the search term, then the filters" do
    params = { "q" => "skull", "f" => { "collection_ssim" => [ "Grainger Museum" ], "has_digital_asset" => [ "with" ] } }

    assert_equal "skull · Grainger Museum, With a digital asset", SavedSearch.default_name(params)
  end

  test "a search with only a term is named for the term, with its spaces tidied" do
    assert_equal "skull cup", SavedSearch.default_name({ "q" => "  skull   cup ", "search_field" => "all_fields" })
  end

  test "a search with only filters is named for the filters" do
    assert_equal "Grainger Museum", SavedSearch.default_name({ "f" => { "collection_ssim" => [ "Grainger Museum" ] } })
  end

  test "a year range reads as from–to, and a one-sided range as the year given" do
    assert_equal "violin · 1900–1950", SavedSearch.default_name({ "q" => "violin", "range" => { "date_range" => { "begin" => "1900", "end" => "1950" } } })
    assert_equal "1900", SavedSearch.default_name({ "range" => { "date_range" => { "begin" => "1900", "end" => "" } } })
  end

  test "an Advanced search is named for the words in its clauses" do
    params = { "op" => "must", "clause" => { "0" => { "field" => "title", "query" => "skull" }, "1" => { "field" => "creator", "query" => "Grainger" }, "2" => { "field" => "date", "query" => "" } } }

    assert_equal "skull Grainger", SavedSearch.default_name(params)
  end

  test "a search with nothing in it is All records" do
    assert_equal "All records", SavedSearch.default_name({})
    assert_equal "All records", SavedSearch.default_name({ "any_assets" => "1" })
  end

  test "a long name is cut to fit the name limit" do
    name = SavedSearch.default_name({ "q" => "word " * 100 })

    assert_equal SavedSearch::NAME_LIMIT, name.length
    assert name.end_with?("...")
  end

  test "symbol keys work as well as string keys" do
    assert_equal "skull", SavedSearch.default_name({ q: "skull" })
  end
end
