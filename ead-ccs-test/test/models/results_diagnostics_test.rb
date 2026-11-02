require "test_helper"

# CCS-43: the plain-language reading of a search that found little.
class ResultsDiagnosticsTest < ActiveSupport::TestCase
  def facets = CatalogController.blacklight_config.facet_fields

  def removals(params) = ResultsDiagnostics.removals(params, facets)

  test "it applies below ten results, to a search or filters, not to a bare page" do
    assert ResultsDiagnostics.applies?(total: 0, params: { "q" => "skull" })
    assert ResultsDiagnostics.applies?(total: 9, params: { "f" => { "collection_ssim" => [ "Grainger Museum" ] } })
    assert ResultsDiagnostics.applies?(total: 3, params: { "clause" => { "0" => { "query" => "x" } } })
    assert_not ResultsDiagnostics.applies?(total: 10, params: { "q" => "skull" })
    assert_not ResultsDiagnostics.applies?(total: 0, params: {})
  end

  test "each filter value is something that can be taken off, leaving the rest of the search" do
    params = { "q" => "skull", "view" => "list", "page" => "2",
               "f" => { "has_digital_asset" => [ "with" ], "collection_ssim" => [ "Grainger Museum", "Medical History Museum" ] } }
    list = removals(params)

    assert_equal 3, list.size
    default = list.find { |item| item.field == "has_digital_asset" }
    assert_equal "With a digital asset", default.label
    assert_equal({ "q" => "skull", "view" => "list", "f" => { "collection_ssim" => [ "Grainger Museum", "Medical History Museum" ] }, "any_assets" => "1" }, default.params)
    one = list.find { |item| item.label.end_with?("Grainger Museum") }
    assert_equal [ "Medical History Museum" ], one.params["f"]["collection_ssim"]
    assert_equal [ "with" ], one.params["f"]["has_digital_asset"]
    assert_nil one.params["any_assets"]
    assert_nil one.params["page"]
  end

  test "inclusive filters and year ranges are listed, and a year range is named by its years" do
    params = { "q" => "x", "f_inclusive" => { "format" => [ "Image" ] }, "range" => { "date_start_isi" => { "begin" => "1900", "end" => "1950" } } }
    list = removals(params)

    assert_equal 2, list.size
    assert_match(/1900–1950/, list.last.label)
    assert_equal({ "q" => "x", "f_inclusive" => { "format" => [ "Image" ] } }, list.last.params)
    assert_equal({ "q" => "x", "range" => { "date_start_isi" => { "begin" => "1900", "end" => "1950" } } }, list.first.params)
  end

  test "a year range with neither year given is not a filter" do
    assert_empty removals({ "q" => "x", "range" => { "date_start_isi" => { "begin" => "", "end" => "" } } })
  end

  test "an open-ended year range reads from or up to" do
    assert_match(/from 1900\z/, removals({ "range" => { "date_start_isi" => { "begin" => "1900", "end" => "" } } }).first.label)
    assert_match(/up to 1950\z/, removals({ "range" => { "date_start_isi" => { "begin" => "", "end" => "1950" } } }).first.label)
  end

  test "malformed filter parameters are ignored" do
    assert_empty removals({ "q" => "x", "f" => "oops", "f_inclusive" => [ 1 ], "range" => "no" })
  end

  test "phrases and words are told apart, and operators are not words" do
    assert_equal [ "human skull", "x" ], ResultsDiagnostics.phrases('a "human skull" b "x"')
    assert_equal %w[a b], ResultsDiagnostics.words('a "human skull" AND b')
  end

  test "how many words a record must contain follows the search's minimum-should-match" do
    assert_equal [ [ 1, 4, 0 ], [ 5, 7, 1 ], [ 8, nil, 2 ] ], ResultsDiagnostics.words_needed("4<-1 7<-2")
    assert_equal [ [ 1, nil, 0 ] ], ResultsDiagnostics.words_needed("")
    assert_equal ResultsDiagnostics.words_needed(SearchBuilder::KEYWORD_MM).first, [ 1, 4, 0 ]
  end
end
