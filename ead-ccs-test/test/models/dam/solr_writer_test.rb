require "test_helper"
require_relative "../../support/dam_fakes"
require_relative "../../support/env_override"

class DamSolrWriterTest < ActiveSupport::TestCase
  include DamFakes
  include EnvOverride

  def asset(id, accession: "1987.0043", format: "image", **attributes)
    DamAsset.create!(DamAsset.attributes_from_api(dam_item(id, accession: accession, format: format)).merge(attributes))
  end

  test "it writes the fields the app reads, linking the DAM's own (non-expiring) embed links" do
    asset("b", display_sequence: 2, licence: "CC BY", producer: "Lee McRae (Photographer)")
    asset("a", display_sequence: 1, licence: "CC BY")
    asset("v", format: "video", licence: "CC BY")
    solr = DamFakes::Solr.new([ { "id" => "emu-1", "accession_number_ssim" => [ "1987.0043" ] } ])

    assert_equal 1, Dam::SolrWriter.new(solr: solr).write([ "1987.0043" ])

    doc = solr.docs["emu-1"]
    assert_equal "https://unimelbourne.widen.net/content/a/jpeg/thumb.jpg", doc["thumbnail_path_ssi"]
    assert_equal %w[a b].map { |id| "https://unimelbourne.widen.net/content/#{id}/jpeg/large.jpg" }, doc["digital_asset_large_paths_ssim"]
    assert_equal 2, doc["digital_asset_paths_ssim"].size
    assert_equal [ "video|video/mp4|https://unimelbourne.widen.net/content/v/original/v|v.jpg".sub("video/mp4", Rack::Mime.mime_type(".jpg")) ], doc["digital_media_ssim"]
    assert_equal true, doc["has_digital_asset_bsi"]
    assert_equal %w[Image Video], doc["digital_asset_format_ssim"].sort
    metadata = doc["digital_asset_metadata_ssm"].map { |json| JSON.parse(json) }
    assert_equal "CC BY", metadata.first["licence"]
    assert_equal "Lee McRae (Photographer)", metadata.second["producer"]
    assert_equal :open, AccessPolicy.tier(SolrDocument.new(doc.merge("digital_asset_metadata_ssm" => doc["digital_asset_metadata_ssm"].first(2))))
    assert_equal 1, solr.commits
  end

  test "a record whose assets a visitor cannot see is not flagged as having one, so it does not sort first" do
    asset("blank", accession: "1")
    asset("icip", accession: "2", licence: "CC BY")
    solr = DamFakes::Solr.new([ { "id" => "blank-rec", "accession_number_ssim" => [ "1" ] },
                                { "id" => "icip-rec", "accession_number_ssim" => [ "2" ], "licence_type_ssim" => [ "ICIP Rights" ] } ])
    Dam::SolrWriter.new(solr: solr).write(%w[1 2])

    %w[blank-rec icip-rec].each do |id|
      assert_equal false, solr.docs[id]["has_digital_asset_bsi"], id
      assert solr.docs[id]["digital_asset_metadata_ssm"].present?, "#{id} keeps its DAM metadata (the page shows the licence and a request link)"
    end
  end

  test "when the DAM fills in a licence, the record's flag follows" do
    record = asset("x")
    solr = DamFakes::Solr.new([ { "id" => "emu-1", "accession_number_ssim" => [ "1987.0043" ] } ])
    writer = Dam::SolrWriter.new(solr: solr)
    writer.write([ "1987.0043" ])
    record.update!(licence: "All Rights reserved (UoM)")
    writer.write([ "1987.0043" ])

    assert_equal true, solr.docs["emu-1"]["has_digital_asset_bsi"]
  end

  test "only records whose DAM fields changed are sent" do
    asset("a")
    solr = DamFakes::Solr.new([ { "id" => "emu-1", "accession_number_ssim" => [ "1987.0043" ] }, { "id" => "emu-2", "accession_number_ssim" => [ "9" ] } ])
    writer = Dam::SolrWriter.new(solr: solr)

    assert_equal 1, writer.write([ "1987.0043", "9" ])
    assert_equal 0, writer.write([ "1987.0043", "9" ])
    assert_equal 1, solr.adds.size
    assert_nil solr.docs["emu-2"]["dam_digest_ssi"], "a record that never had DAM assets is left alone"
  end

  test "a record whose assets were all deleted has its DAM fields removed" do
    asset("a")
    solr = DamFakes::Solr.new([ { "id" => "emu-1", "accession_number_ssim" => [ "1987.0043" ], "title_tsim" => [ "Kept" ] } ])
    writer = Dam::SolrWriter.new(solr: solr)
    writer.write([ "1987.0043" ])
    DamAsset.update_all(deleted_at: Time.current)
    writer.write([ "1987.0043" ])

    doc = solr.docs["emu-1"]
    Dam::SolrWriter::FIELDS.each { |field| assert_not doc.key?(field), field }
    assert_equal [ "Kept" ], doc["title_tsim"]
  end

  test "an accession number two records share goes to the record of the asset's collection" do
    asset("g", accession: "0.0013", collection: "Grainger Museum Collection")
    asset("u", accession: "0.0013", collection: "University Art Collection")
    solr = DamFakes::Solr.new([
      { "id" => "grainger", "accession_number_ssim" => [ "0.0013" ], "collection_ssim" => [ "Grainger Museum Collection" ] },
      { "id" => "art", "accession_number_ssim" => [ "0.0013" ], "collection_ssim" => [ "University Art Collection" ] }
    ])
    Dam::SolrWriter.new(solr: solr).write([ "0.0013" ])

    assert_equal [ "g" ], solr.docs["grainger"]["digital_asset_metadata_ssm"].map { |json| JSON.parse(json)["dam_id"] }
    assert_equal [ "u" ], solr.docs["art"]["digital_asset_metadata_ssm"].map { |json| JSON.parse(json)["dam_id"] }
  end

  test "an accession number with a quote is escaped in the query" do
    asset("q", accession: %(1"2))
    solr = DamFakes::Solr.new([ { "id" => "emu-q", "accession_number_ssim" => [ %(1"2) ] } ])

    assert_equal 1, Dam::SolrWriter.new(solr: solr).write([ %(1"2) ])
  end

  test "it never writes without a core of its own" do
    with_env("DAM_SOLR_URL" => nil) do
      error = assert_raises(Dam::Error) { Dam::SolrWriter.from_env }
      assert_match "DAM_SOLR_URL", error.message
    end
  end
end
