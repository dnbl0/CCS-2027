require "test_helper"
require "tmpdir"

# CCS-149: characterisation tests for the CSV sources (Collections::Source, VernonSource, EmuSource). They pin what a row becomes in Solr
# today, with small CSV files written for each test; the real exports are 20 MB and are only checked by data_model_test.rb.
class SourcesTest < ActiveSupport::TestCase
  BOM = "﻿".freeze

  # headers: the export's column names (a header may repeat); rows: arrays in the same order
  def source(klass, headers, *rows)
    @dir ||= Dir.mktmpdir
    path = File.join(@dir, "#{klass.name.demodulize}.csv")
    File.write(path, BOM + CSV.generate { |csv| ([ headers ] + rows).each { |row| csv << row } })
    klass.new(path)
  end

  teardown { FileUtils.remove_entry(@dir) if @dir }

  VERNON_HEADERS = [ "Accession Number", "Source Reference Number", "Collection", "Named Collection", "Classification", "Classification",
                     "Classification", "Classification", "Primary Title", "Creator Name", "Associated Entities (subject)",
                     "Place of Production", "Object type -", "Production Date", "Description", "Credit Line", "Rights",
                     "Restricted and Notes for DAM" ].freeze

  def vernon_row(accession: "TEST-1", rights: "[Copyright - Current] Ross, Andrew", date: "Circa 1845", classification: "Scientific Equipment", **)
    [ accession, "MU001", "Medical History Museum", "", "", "", classification, "", "Microscope", "Andrew Ross; John Smith", "", "London, England",
      "equipment; microscopes", date, "Brass", "Gift of X", rights, "Not for publishing" ]
  end

  test "a Vernon row becomes one Solr document under the source's id prefix" do
    document = source(Collections::VernonSource, VERNON_HEADERS, vernon_row).each_document.first

    assert_equal "vernon-TEST-1", document["id"]
    assert_equal "vernon", document["source_system_ssi"]
    assert_equal [ "TEST-1" ], document["accession_number_ssim"]
    assert_equal [ "Medical History Museum" ], document["collection_ssim"]
    assert_equal [ "Microscope" ], document["title_tsim"]
    assert_equal "Microscope", document["title_si"]
    assert_equal [ "Object" ], document["format"]
  end

  test "Vernon lists are split on semicolons, and the Classification that holds a value is the one used" do
    document = source(Collections::VernonSource, VERNON_HEADERS, vernon_row).each_document.first

    assert_equal [ "Andrew Ross", "John Smith" ], document["creator_ssim"]
    assert_equal [ "equipment", "microscopes" ], document["object_type_ssim"]
    assert_equal [ "Scientific Equipment" ], document["classification_ssim"]
  end

  test "Vernon dates give a year range, the licence is the bracketed word of the rights note, and the restriction stays out of the searchable fields" do
    document = source(Collections::VernonSource, VERNON_HEADERS, vernon_row).each_document.first

    assert_equal [ 1845, 1845 ], document.values_at("date_start_isi", "date_end_isi")
    assert_equal [ "Copyright - Current" ], document["licence_type_ssim"]
    assert_equal "Not for publishing", document["restrictions_tsi"]
    assert_not document.key?("restrictions_tsim")
  end

  test "a field with nothing in it is left out of the document, not sent empty" do
    document = source(Collections::VernonSource, VERNON_HEADERS, vernon_row(date: "", rights: "")).each_document.first

    assert_not document.key?("date_start_isi")
    assert_not document.key?("production_date_ssim")
    assert_not document.key?("licence_type_ssim")
  end

  test "blank lines and rows without an accession number produce no document" do
    rows = [ vernon_row, [ "" ] * VERNON_HEADERS.size, vernon_row(accession: ""), vernon_row(accession: "TEST-2") ]
    ids = source(Collections::VernonSource, VERNON_HEADERS, *rows).each_document.map { |d| d["id"] }

    assert_equal [ "vernon-TEST-1", "vernon-TEST-2" ], ids
  end

  test "an id has anything but letters, digits and . _ - replaced, so it is safe in a URL" do
    document = source(Collections::VernonSource, VERNON_HEADERS, vernon_row(accession: "MU 1/2 (a)")).each_document.first

    assert_equal "vernon-MU_1_2_a_", document["id"]
  end

  test "an empty file is refused and a missing column is named" do
    path = File.join(Dir.mktmpdir.tap { |dir| @dir = dir }, "empty.csv")
    File.write(path, "")
    assert_raises(RuntimeError) { Collections::VernonSource.new(path).each_document.to_a }

    error = assert_raises(Collections::Row::UnknownHeader) { source(Collections::VernonSource, [ "Accession Number" ], [ "A" ]).each_document.to_a }
    assert_match(/no column named/, error.message)
  end

  test "the base Source cannot build a document" do
    assert_raises(NotImplementedError) { source(Collections::Source, [ "A" ], [ "1" ]).each_document.to_a }
  end

  test "the name is the class name without Source, and each_document without a block is an enumerator" do
    vernon = source(Collections::VernonSource, VERNON_HEADERS, vernon_row)

    assert_equal "vernon", vernon.name
    assert_kind_of Enumerator, vernon.each_document
  end

  # Every header the EMu source reads; a row is a hash of the few columns a test cares about, the rest empty
  EMU = Collections::EmuSource
  EMU_HEADERS = (EMU.constants(false).map { |name| EMU.const_get(name) }.grep(String) + EMU::CREATION_PLACES).uniq.freeze

  def emu_source(*rows)
    source(EMU, EMU_HEADERS, *rows.map { |values| EMU_HEADERS.map { |header| values.fetch(header, "") } })
  end

  def emu_row(**overrides)
    { EMU::IRN => "9044", EMU::ACCESSION => "0.007", EMU::COLLECTION => "Grainger Museum Collection", EMU::TITLE => "A violin",
      EMU::DATE_CREATED => "c. 1920", EMU::CREATOR => "Grainger, Percy\\,Other, Person", EMU::ROLE => "composer\\,editor",
      EMU::BIRTH => "8 July 1882\\,", EMU::DEATH => "20 February 1961\\,", EMU::COPYRIGHT => "[Copyright] Grainger",
      EMU::RECORD_STATUS => "Public", EMU::RECORD_TYPE => "Object", EMU::OBJECT_NAME => "Violin", EMU::LEVEL_OF_DESC => "Item",
      EMU::PRIMARY_AREA => "Music", EMU::SECONDARY_TYPE => "Strings", EMU::SUBJECT => "Instruments", EMU::SITE => "Melbourne",
      EMU::CREATION_PLACES.first => "Australia" }.merge(overrides.transform_keys { |key| EMU.const_get(key.to_s.upcase) })
  end

  test "an EMu row becomes a document: IRN is the id, backslash-comma separates entries and the creator line is built from the matching columns" do
    document = emu_source(emu_row).each_document.first

    assert_equal "emu-9044", document["id"]
    assert_equal "9044", document["source_identifier_ssi"]
    assert_equal [ "A violin" ], document["title_tsim"]
    assert_equal [ "Grainger, Percy", "Other, Person" ], document["creator_ssim"]
    assert_equal [ "Grainger, Percy (8 July 1882 – 20 February 1961) Composer", "Other, Person Editor" ], document["creator_display_ssim"]
    assert_equal [ "Violin", "Item" ], document["object_type_ssim"]
    assert_equal [ "Music", "Strings" ], document["classification_ssim"]
    assert_equal [ "Instruments" ], document["subject_ssim"]
    assert_equal [ "Melbourne", "Australia" ], document["production_place_ssim"]
    assert_equal "Public", document["access_condition_ssi"]
  end

  test "an EMu Grainger accession number that lost its zeros in the spreadsheet is restored" do
    assert_equal [ "00.0070" ], emu_source(emu_row).each_document.first["accession_number_ssim"]
    assert_equal [ "0.007" ], emu_source(emu_row(collection: "University Art Collection")).each_document.first["accession_number_ssim"]
  end

  test "EMu takes the year range from the Earliest and Latest columns when they have one, and otherwise from the date text" do
    explicit = emu_source(emu_row(date_start: "1918", date_end: "1920", date_created: "1950")).each_document.first
    scraped = emu_source(emu_row(date_created: "1948-1950")).each_document.first

    assert_equal [ 1918, 1920 ], explicit.values_at("date_start_isi", "date_end_isi")
    assert_equal [ 1948, 1950 ], scraped.values_at("date_start_isi", "date_end_isi")
  end

  test "an EMu row with no title falls back to the taxon, and a row with no IRN is skipped" do
    documents = emu_source(emu_row(title: "", taxon: "Thylacinus cynocephalus"), emu_row(irn: "")).each_document.to_a

    assert_equal 1, documents.size
    assert_equal [ "Thylacinus cynocephalus" ], documents.first["title_tsim"]
    assert_equal "Thylacinus cynocephalus", documents.first["title_si"]
  end
end
