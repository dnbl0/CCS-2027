require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

class RecordLayoutTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  def page = Capybara::Node::Simple.new(rendered_content)

  def presenter(fields)
    document = SolrDocument.new({ "id" => "emu-1" }.merge(fields))
    Blacklight::DocumentPresenter.new(document, nil, CatalogController.blacklight_config)
  end

  def component(fields)
    NexusCcs::RecordDocumentComponent.new(document: presenter(fields), id: "document", component: :div, show: true)
  end

  FIELDS = {
    "title_tsim" => [ "Kangaroo-pouch tone-tool" ], "object_type_ssim" => [ "tone tool" ], "production_date_ssim" => [ "1952" ],
    "creator_ssim" => [ "Grainger, Percy Aldridge" ], "material_ssim" => [ "Paper" ], "collection_ssim" => [ "Grainger Museum Collection" ],
    "rights_ssim" => [ "© Grainger, Percy Aldridge" ], "credit_line_tsim" => [ "Grainger Museum Collection, University of Melbourne." ],
    "format" => [ "Object" ]
  }.freeze

  test "the heading is the record's title" do
    assert_equal "Kangaroo-pouch tone-tool", component(FIELDS).heading
  end

  test "the details list leaves out what the header, the Key facts and Copyright and use show: no Title, UoM ID, Collection, date or materials" do
    labels = component(FIELDS).rows.map(&:label)

    assert_not_includes labels, "Title"
    assert_not_includes labels, "UoM ID"
    assert_not_includes labels, "Collection"
    assert_not_includes labels, "Date"
    assert_not_includes labels, "Materials"
    assert_includes labels, "Object Type"
  end

  test "the UoM ID names the EMu system: M&C's EMu records are emu-umc, Vernon ids are unchanged" do
    assert_equal "emu-umc-1", component(FIELDS).uom_id
    assert_equal "vernon-MHM00394", component(FIELDS.merge("id" => "vernon-MHM00394")).uom_id
  end

  test "the identifier is the collection, accession number and UoM ID (CCS-22)" do
    assert_equal "Grainger Museum Collection, accession number 00.0001, UoM ID emu-umc-1",
                 component(FIELDS.merge("accession_number_ssim" => [ "00.0001" ])).identifier
  end

  test "the rights fields are in the Copyright card, not in the details list" do
    c = component(FIELDS)
    fields = c.rows.map(&:field)

    assert_not_includes fields, "rights_ssim"
    assert_not_includes fields, "credit_line_tsim"
    assert c.rights_recorded?
    assert_equal "Kangaroo-pouch tone-tool. 1952. Grainger, Percy Aldridge. Paper. © Grainger, Percy Aldridge. Grainger Museum Collection.", c.caption
  end

  test "a record with no rights fields has no rights recorded, and the Copyright card says so" do
    c = component("title_tsim" => [ "Untitled" ])

    assert_not c.rights_recorded?
    # (the card's markup is checked on real record pages: test/integration/rights_display_test.rb)
  end

  test "the layout is one column, then 7/5 columns from 1200px, with a plain (not sticky) right column" do
    css = Rails.root.join("app/assets/stylesheets/components/record_page.css").read

    assert_match(/@media \(min-width: 1200px\) \{\s+\.record-layout \{\s+grid-template-columns: minmax\(0, 7fr\) minmax\(0, 5fr\);/, css)
    assert_no_match(/position: sticky/, css)
  end

  test "the document component for a record is registered with Blacklight" do
    assert_equal NexusCcs::RecordDocumentComponent, CatalogController.blacklight_config.view_config(:show).document_component
  end

  test "the clipboard controller copies text from an input or a data-copy element and keeps a button's icon" do
    js = Rails.root.join("app/javascript/controllers/clipboard_controller.js").read
    assert_includes js, "source.value ?? source.dataset.copy"
    assert_includes js, 'static targets = ["source", "button", "status", "label"]'
  end

  test "the Responsible collection link opens the whole collection, as the Search collections menu does" do
    assert_equal BrowseMenu.query(BrowseMenu::COLLECTION_FIELD, "Grainger Museum Collection"), component(FIELDS).responsible_collection_query
  end

  test "every link to the record's collection or named collection opens all of it; other details keep the search's default" do
    c = component(FIELDS)

    assert_equal BrowseMenu.query("collection_ssim", "Grainger Museum Collection"), c.filter_query("collection_ssim", "Grainger Museum Collection")
    assert_equal BrowseMenu.query("named_collection_ssim", "Rupert Bunny Collection"), c.filter_query("named_collection_ssim", "Rupert Bunny Collection")
    assert_equal({ f: { "material_ssim" => [ "Paper" ] } }, c.filter_query("material_ssim", "Paper"))
    assert_equal c.filter_query("collection_ssim", "Grainger Museum Collection"), c.responsible_collection_query
  end
end
