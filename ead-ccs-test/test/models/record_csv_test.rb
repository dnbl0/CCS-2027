require "test_helper"
require "csv"

class RecordCsvTest < ActiveSupport::TestCase
  FIELDS = [ [ "Creator", "creator_ssim" ], [ "Description", "description_tsim" ], [ "Subject", "subject_ssim" ], [ "Date", "production_date_ssim" ] ].freeze
  LINK = "https://ccs.example/catalog/emu-400329"

  def csv_for(fields)
    document = SolrDocument.new({ "id" => "emu-400329", "title_tsim" => [ "Violin" ] }.merge(fields))
    RecordCsv.new(document, show_fields: FIELDS, persistent_link: LINK)
  end

  def parse(export) = CSV.parse(export.to_csv.delete_prefix(RecordCsv::BOM))

  test "one header row of labels and one row of values: UoM ID, Title, the fields it has, the persistent link" do
    header, row = parse(csv_for("creator_ssim" => [ "Grainger, Percy" ], "production_date_ssim" => [ "1952" ]))

    assert_equal [ "UoM ID", "Title", "Creator", "Date", "Persistent link" ], header
    assert_equal [ "emu-umc-400329", "Violin", "Grainger, Percy", "1952", LINK ], row
  end

  test "several values are joined, and commas, quotes and line breaks are escaped" do
    export = csv_for("subject_ssim" => [ "Music", "Pianos" ], "description_tsim" => [ "A \"fine\" piano,\nwith keys" ])
    header, row = parse(export)

    assert_equal "Music | Pianos", row[header.index("Subject")]
    assert_equal "A \"fine\" piano,\nwith keys", row[header.index("Description")]
  end

  test "a value that would run as a formula is neutralised" do
    header, row = parse(csv_for("description_tsim" => [ "=cmd|' /C calc'!A0" ], "creator_ssim" => [ "@evil" ]))

    assert_equal "'=cmd|' /C calc'!A0", row[header.index("Description")]
    assert_equal "'@evil", row[header.index("Creator")]
  end

  test "the file is UTF-8 with a byte order mark, and keeps non-ASCII text" do
    export = csv_for("creator_ssim" => [ "Wurundjeri Māori" ])

    assert_equal Encoding::UTF_8, export.to_csv.encoding
    assert export.to_csv.start_with?("﻿")
    assert_includes parse(export).last, "Wurundjeri Māori"
  end

  test "the file name comes from the id and holds only safe characters" do
    assert_equal "ccs-emu-400329-metadata.csv", csv_for({}).filename
    document = SolrDocument.new("id" => "a/b\\..\"c d")
    assert_equal "ccs-a_b_.._c_d-metadata.csv", RecordCsv.new(document, show_fields: [], persistent_link: LINK).filename
  end
end
