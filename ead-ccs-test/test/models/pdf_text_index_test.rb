require "test_helper"
require_relative "../support/canned_search"

# CCS-36: the Full text (PDF) search is offered only when the core has its field, and says "Found in PDF".
class PdfTextIndexTest < ActionDispatch::IntegrationTest
  include CannedSearch

  test "it is off until the schema says the field exists; an unreachable core is off" do
    assert_not PdfTextIndex.available?
    connection = Blacklight.default_index.connection
    asked = 0
    connection.define_singleton_method(:get) { |*, **| asked += 1; { "schema" => { "fields" => { "pdf_text_tim" => {} } } } }
    PdfTextIndex.probe = true

    assert PdfTextIndex.refresh!
    assert PdfTextIndex.refresh!
    assert_equal 1, asked

    PdfTextIndex.force(nil)
    connection.define_singleton_method(:get) { |*, **| raise Errno::ECONNREFUSED }
    assert_not PdfTextIndex.refresh!
  ensure
    connection.singleton_class.send(:remove_method, :get)
    PdfTextIndex.probe = nil
  end

  test "the search option follows the answer, and the schema and handler have the field" do
    field = CatalogController.blacklight_config.search_fields["full_text"]
    assert_not field.if.call(nil, field)
    PdfTextIndex.force(true)
    assert field.if.call(nil, field)
    assert_equal "${pdf_qf}", field.solr_parameters[:qf]
    assert_match(/name="pdf_text_tim" type="text" stored="false" indexed="true"/, File.read(Rails.root.join("solr/conf/schema.xml")))
    assert_match(/pdf_qf/, File.read(Rails.root.join("solr/conf/solrconfig.xml")))
  end

  test "a Full text search asks for no highlighting, and each result says Found in PDF" do
    state = Blacklight::SearchState.new({ q: "violin", search_field: "full_text" }.with_indifferent_access, CatalogController.blacklight_config)
    assert_empty SearchHighlighting.parameters(state)

    docs = [ { "id" => "emu-1", "title_tsim" => [ "Catalogue" ], "object_type_ssim" => [ "book" ] } ]
    with_seeded_menu_cache do
      with_canned_search(canned_response(docs)) { get "/catalog", params: { q: "violin", search_field: "full_text", any_assets: "1", view: "list" } }
    end

    assert_response :success
    assert_select "article[data-document-id='emu-1'] .result-card__matched", text: "Found in PDF"

    with_seeded_menu_cache do
      with_canned_search(canned_response(docs, highlighting: { "emu-1" => { "title_tsim" => [ "<mark>Catalogue</mark>" ] } })) { get "/catalog", params: { q: "catalogue", any_assets: "1", view: "list" } }
    end
    assert_select ".result-card__matched", text: "Found in PDF", count: 0
  end
end
