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

  # CCS-400: the sheet "CCS Field Labels", its FINAL SEQUENCE ORDER and display rules
  SHEET = FIELDS.merge(
    "description_tsim" => [ "A tool for tuning." ], "accession_number_ssim" => [ "00.0001" ], "creator_display_ssm" => [ "Grainger, Percy Aldridge (1882 – 1961) maker" ],
    "production_place_ssim" => [ "Australia", "Victoria" ], "classification_ssim" => [ "Music", "Instruments" ], "dimensions_ssm" => [ "10 x 4 cm" ],
    "inscription_tsim" => [ "Signed lower right" ], "parent_record_ssi" => "[00.0000] tone-tool set", "source_url_ssi" => "https://collections.example.org/1"
  )

  test "the details follow the sheet's sequence and labels, leaving out the title, the description and the rights Use and access shows" do
    rows = component(SHEET).detail_rows

    assert_equal rows.map(&:seq), rows.map(&:seq).sort
    labels = rows.map(&:label)
    assert_equal %w[Object\ Type Date Creator Place Material Measurements Inscription Classification Collection Accession\ Number Source\ URL Related\ Record], labels
    %w[Title Description Credit\ Line Copyright].each { |label| assert_not_includes labels, label }
  end

  test "the sheet's display rules: creator in the person form, place and classification joined, the related record marked Parent" do
    rows = component(SHEET).detail_rows.index_by(&:label)

    assert_equal [ "Grainger, Percy Aldridge (b. 1882 - d. 1961) maker" ], rows["Creator"].values
    assert_equal ", ", rows["Place"].join
    assert_equal " - ", rows["Classification"].join
    assert_equal [ "Parent - [00.0000] tone-tool set" ], rows["Related Record"].values
    assert_equal [ "10 x 4 cm" ], rows["Measurements"].values
  end

  test "a field with no value has no row, and a record with no display creator falls back to its names" do
    labels = component(FIELDS).detail_rows.map(&:label)

    assert_not_includes labels, "Measurements"
    assert_not_includes labels, "Source URL"
    assert_equal [ "Grainger, Percy Aldridge" ], component(FIELDS).detail_rows.find { |row| row.label == "Creator" }.values
  end

  test "who made it and where are the key rows under the title; Object details holds the rest, in the sheet's order" do
    record = component(SHEET)

    assert_equal %w[Creator Place], record.lead_rows.map(&:label)
    labels = record.object_rows.map(&:label)
    assert_equal %w[Object\ Type Date Material Measurements Inscription Classification Collection Accession\ Number Source\ URL Related\ Record], labels
    assert_equal record.object_rows.map(&:seq), record.object_rows.map(&:seq).sort
  end

  test "associated names: each maker by name, linked to their browse page where there is one, with the record's dates and role under it" do
    names = component(SHEET).associated_names
    assert_equal "Grainger, Percy Aldridge", names.first[0]
    assert_equal "Maker, b. 1882 - d. 1961", names.first[2]
  end

  test "Object overview holds the key facts in the sheet's order, the credit line and copyright among them" do
    labels = component(SHEET.merge("rights_ssim" => [ "© Grainger" ])).overview_rows.map(&:label)
    assert_equal [ "Object Type", "Place", "Material", "Measurements", "Classification", "Collection", "Accession Number", "Credit line", "Copyright" ], labels
  end

  test "the record's collection, with the way to the rest of it" do
    record = component(SHEET.merge("collection_ssim" => [ "Grainger Museum Collection" ]))
    record.define_singleton_method(:value_link) { |_row, value| "/catalog?collection=#{value}" }
    name, path = record.collection_link
    assert_equal "Grainger Museum Collection", name
    assert_predicate path, :present?
  end

  test "Use and access: the rights items in CCS-27's order; caption and terms only with a digital asset" do
    items = component(SHEET.merge("rights_ssim" => [ "© Grainger" ])).rights_items.map(&:first)

    assert_equal [ "Accession number", "Credit line", "Copyright" ], items
    assert_equal :none, component(SHEET).access_state
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
