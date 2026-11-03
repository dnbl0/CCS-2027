require "test_helper"
require_relative "../support/canned_search"

# The rule builder and the open-licence switch, with Solr stood in for (so the CI job without a core runs them).
class AdvancedRulesIntegrationTest < ActionDispatch::IntegrationTest
  include CannedSearch

  DOC = { "id" => "emu-1", "title_tsim" => [ "Bird" ], "creator_ssim" => [ "Unknown" ] }.freeze

  def visit(path, total: 3)
    with_seeded_menu_cache do
      with_canned_search(canned_response(Array.new(total) { |n| DOC.merge("id" => "emu-#{n}") }, total: total)) do |seen|
        get path
        @seen = seen
      end
    end
  end

  def sent_json = @seen.map { |params| params["json"] || params[:json] }.compact.first

  test "the results page reads a does-not-contain rule into the Solr query and shows it in its pill" do
    visit "/catalog?op=must&clause[0][field]=title&clause[0][match]=all&clause[0][query]=skull&clause[1][field]=title&clause[1][match]=not&clause[1][query]=bone"

    assert_response :success
    assert_equal 1, sent_json[:query][:bool][:must].size
    assert_equal 1, sent_json[:query][:bool][:must_not].size
    assert_select ".constraint", text: /Title\s*does not contain “bone”/
    assert_select ".constraint", text: /Title\s*contains all of “skull”/
  end

  test "a has-a-value rule alone is a search" do
    visit "/catalog?clause[0][field]=creator&clause[0][match]=present"

    assert_response :success
    assert_select ".constraint", text: /Creator\s*has a value/
  end

  test "a form sent with only a blank rule goes back to the form, and a presence rule does not" do
    get "/catalog?op=must&clause[0][field]=title&clause[0][match]=all&clause[0][query]="
    assert_redirected_to "/catalog/advanced?op=must"
  end

  test "an old address with a does-not-contain row still reads" do
    visit "/catalog?clause[0][field]=title&clause[0][op]=must_not&clause[0][query]=skull"

    assert_select ".constraint", text: /Title\s*does not contain “skull”/
  end

  test "the Advanced search form has a fixed row and a match menu for each field, and Add another rule works without JavaScript" do
    visit "/catalog/advanced"

    assert_select "form.advanced .advanced-rule--fixed", 5
    assert_select "select[name='clause[1][match]'] option", 7
    assert_select "select[name='clause[4][match]'] option[value=begins][disabled]"
    assert_select "button[name=add_rule][formaction*='/catalog/advanced']"
    assert_select ".advanced-rules__extras fieldset", 0

    visit "/catalog/advanced?clause[1][field]=title&clause[1][match]=not&clause[1][query]=skull&clause[5][field]=title&clause[5][query]=a&add_rule=1"

    assert_select ".advanced-rules__extras fieldset", 2 # the one in the address, and the new blank one
    assert_select "select[name='clause[5][field]']"
    assert_select "select[name='clause[6][field]'][autofocus]"
    assert_select "input[name='clause[1][query]'][value=skull]"
  end

  test "remove_rule without JavaScript leaves that extra row out" do
    visit "/catalog/advanced?clause[1][field]=title&clause[1][query]=a&clause[7][field]=title&clause[7][query]=b&clause[8][field]=title&clause[8][query]=c&remove_rule=7"

    assert_select ".advanced-rules__extras fieldset", 1
    assert_select ".advanced-rules__extras fieldset input[value=c]"
    assert_select ".advanced-rules__extras fieldset input[value=b]", 0
  end

  test "the switch is in the sidebar, off, and adds the filter to the search; on, it is a pill and the form takes it off" do
    visit "/catalog?q=skull&f[has_digital_asset][]=with&search_field=all_fields"

    assert_select "button[role=switch][aria-checked=false]", text: /Open licence \(public domain\)/
    assert_select "form.free-reuse__form input[name='f[free_reuse][]']", 1 # the toggled search carries the filter

    visit "/catalog?q=skull&f[has_digital_asset][]=with&f[free_reuse][]=open&search_field=all_fields"

    assert_select "button[role=switch][aria-checked=true]"
    assert_select "form.free-reuse__form input[name='f[free_reuse][]']", 0
    assert_select ".constraint", text: /Reuse\s*Open licence \(public domain\)/
    assert @seen.any? { |params| Array(params["fq"]).any? { |fq| fq.include?("licence_type_ssim") } }
  end

  test "the switch is a search filter alongside the default digital asset filter" do
    get "/catalog?q=skull&f[free_reuse][]=open"

    assert_redirected_to(/f%5Bhas_digital_asset%5D%5B%5D=with/)
    assert_match(/free_reuse/, response.location)
  end

  test "the switch on Advanced search is a checkbox that sends f_inclusive" do
    visit "/catalog/advanced"

    assert_select "input[type=checkbox][role=switch][name='f_inclusive[free_reuse][]'][value=open]"
  end

  test "a saved search is named by its rules and the switch" do
    name = SavedSearch.default_name("clause" => { "0" => { "field" => "title", "match" => "not", "query" => "skull" }, "1" => { "field" => "creator", "query" => "ann" } },
                                    "f" => { "free_reuse" => [ "open" ] })

    assert_equal "Title does not contain “skull” ann · Open licence (public domain)", name
  end

  test "the why panel names a rule as it is read, and counts the switch" do
    component = NexusCcs::SearchDiagnosticsComponent.new(response: Struct.new(:total).new(0), config: CatalogController.blacklight_config,
      params: { "clause" => { "0" => { "field" => "title", "match" => "not", "query" => "skull" } }, "f" => { "free_reuse" => [ "open" ] } })

    assert_equal [ [ "Title", "must_not", "skull" ] ], component.clauses.map { |clause| [ clause.field, clause.op, clause.query ] }
    assert_equal "Title must not contain skull.", I18n.t("nexus_ccs.diagnostics.clause.must_not", field: "Title", query: "skull")
    assert_equal [ "Open licence (public domain)" ], component.removals.map(&:label)
  end
end
