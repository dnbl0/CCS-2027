require "test_helper"
require_relative "../../support/colour_fakes"

# rake colour:write (Colour::IndexWriter) and rake colour:neighbours (Colour::Neighbours)
class Colour::IndexWriterTest < ActiveSupport::TestCase
  THUMB = "https://unimelbourne.widen.net/content/a/jpeg/a.jpg"

  def colours(id, buckets, hexes, histogram: {}, image_url: THUMB)
    RecordColour.create!(record_id: id, image_url: image_url, buckets: buckets, palette: hexes.map { |hex| { "hex" => hex } },
                         histogram: histogram, extracted_at: Time.current)
  end

  test "colour names, hex values and a digest are written as atomic updates, for changed records only" do
    colours("a", %w[red blue], %w[#d62828 #1d4ed8])
    colours("same", %w[red], %w[#d62828])
    same = Colour::IndexWriter.fields_for({ "has_digital_asset_bsi" => true, "thumbnail_path_ssi" => THUMB }, [ THUMB, [ { "hex" => "#d62828" } ], %w[red] ])
    core = FakeWritableCore.new([
      { id: "a", has_digital_asset_bsi: true, thumbnail_path_ssi: THUMB },
      { id: "same", has_digital_asset_bsi: true, thumbnail_path_ssi: THUMB, colour_digest_ssi: same["colour_digest_ssi"] },
      { id: "withdrawn", has_digital_asset_bsi: false, thumbnail_path_ssi: THUMB, colour_digest_ssi: "old" },
      { id: "never", has_digital_asset_bsi: true, thumbnail_path_ssi: THUMB }
    ])

    assert_equal 2, Colour::IndexWriter.new(solr: core).write
    update = core.added.find { |doc| doc["id"] == "a" }
    assert_equal({ "set" => %w[red blue] }, update["colour_ssim"])
    assert_equal({ "set" => %w[#d62828 #1d4ed8] }, update["colour_palette_ssm"])
    assert_match(/\A\h{64}\z/, update["colour_digest_ssi"]["set"])
    withdrawn = core.added.find { |doc| doc["id"] == "withdrawn" }
    assert_equal({ "set" => nil }, withdrawn["colour_ssim"], "a record no longer viewable loses its colours")
    assert_equal 1, core.commits
  end

  test "colours of an older thumbnail are not written" do
    fields = Colour::IndexWriter.fields_for({ "has_digital_asset_bsi" => true, "thumbnail_path_ssi" => "https://new" }, [ THUMB, [], %w[red] ])
    assert_nil fields["colour_ssim"]
  end

  test "neighbours: the closest records by colour histogram, closest first, none past the distance limit" do
    colours("red", %w[red], [ "#ff0000" ], histogram: { "48" => 1.0 })
    colours("mostly-red", %w[red], [ "#ff0000" ], histogram: { "48" => 0.8, "3" => 0.2 })
    colours("half-red", %w[red blue], [ "#ff0000" ], histogram: { "48" => 0.5, "3" => 0.5 })
    colours("blue", %w[blue], [ "#0000ff" ], histogram: { "3" => 1.0 })

    assert_equal 4, Colour::Neighbours.new.run
    assert_equal %w[mostly-red half-red], ColourNeighbour.ids_for("red")
    assert_equal %w[half-red], ColourNeighbour.ids_for("blue"), "mostly-red is too far (0.8)"
    assert_in_delta 0.2, Colour::Neighbours.distance([ 1.0 ] + [ 0.0 ] * 63, [ 0.8, 0.2 ] + [ 0.0 ] * 62), 0.0001
  end
end
