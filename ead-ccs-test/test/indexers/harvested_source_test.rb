require "test_helper"
require "tmpdir"

class HarvestedSourceTest < ActiveSupport::TestCase
  HEADERS = %w[collection source id title description keywords registration_number date maker_or_collector place
               classification sub_collection image_url image_alt record_url file_name file_format].freeze

  def row(**overrides)
    values = {
      "collection" => "Burnley Campus Archives", "source" => "Victorian Collections", "id" => "5b74aa45",
      "title" => "Photograph, Burnley students, 1950", "description" => "Students in the gardens.", "keywords" => "students, gardens",
      "registration_number" => "BUR.0001", "date" => "c. 1950", "maker_or_collector" => "J. Smith; A. Jones", "place" => "Burnley",
      "classification" => "", "sub_collection" => "", "image_url" => "https://victoriancollections.net.au/media/a.jpg",
      "record_url" => "https://victoriancollections.net.au/items/5b74aa45"
    }.merge(overrides.transform_keys(&:to_s))
    HEADERS.map { |header| values[header] }
  end

  def documents(*rows)
    @dir = Dir.mktmpdir
    path = File.join(@dir, "harvested.csv")
    File.write(path, CSV.generate { |csv| ([ HEADERS ] + rows).each { |r| csv << r } })
    Collections::HarvestedSource.new(path).each_document.to_a
  end

  teardown { FileUtils.remove_entry(@dir) if @dir }

  test "a row becomes a document in its collection, under the harvested id prefix, with its source link" do
    document = documents(row).first

    assert_equal "harvested-5b74aa45", document["id"]
    assert_equal "harvested", document["source_system_ssi"]
    assert_equal [ "Burnley Campus Archives" ], document["collection_ssim"]
    assert_equal [ "BUR.0001" ], document["accession_number_ssim"]
    assert_equal "https://victoriancollections.net.au/items/5b74aa45", document["source_url_ssi"]
    assert_equal [ "Record from Victorian Collections" ], document["credit_line_tsim"]
  end

  test "makers split on semicolons, keywords on commas, and the date gives a year range" do
    document = documents(row).first

    assert_equal [ "J. Smith", "A. Jones" ], document["creator_display_ssim"]
    assert_equal [ "students", "gardens" ], document["subject_ssim"]
    assert_equal [ 1950, 1950 ], document.values_at("date_start_isi", "date_end_isi")
  end

  test "a remote image is the thumbnail and the record page image; no licence is claimed" do
    document = documents(row).first

    assert_equal "https://victoriancollections.net.au/media/a.jpg", document["thumbnail_path_ssi"]
    assert_equal [ "https://victoriancollections.net.au/media/a.jpg" ], document["digital_asset_large_paths_ssim"]
    assert_equal true, document["has_digital_asset_bsi"]
    assert_not document.key?("licence_type_ssim")
  end

  test "a row without an image has no image fields, and rows without an id or title are skipped" do
    docs = documents(row(image_url: ""), row(id: ""), row(id: "x2", title: ""))

    assert_equal 1, docs.size
    assert_not docs.first.key?("thumbnail_path_ssi")
    assert_not docs.first.key?("has_digital_asset_bsi")
  end
end
