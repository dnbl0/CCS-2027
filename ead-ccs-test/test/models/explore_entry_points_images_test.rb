# frozen_string_literal: true

require "test_helper"

# The example picture of each Explore collection tile: only a record whose asset anyone may download and that is not sensitive (AccessPolicy, Sensitivity)
class ExploreEntryPointsImagesTest < ActiveSupport::TestCase
  PATH = "/digital-assets/thumbs/0000_013_1_pf.jpg"

  def doc(id, fields = {})
    SolrDocument.new({ "id" => id, "title_tsim" => [ "Record #{id}" ], "thumbnail_path_ssi" => PATH, "licence_type_ssim" => [ "Public domain - Copyright expired" ] }.merge(fields))
  end

  def with_documents(documents)
    response = Struct.new(:documents).new(documents)
    original = Discovery.method(:search)
    Discovery.define_singleton_method(:search) { |_params| response }
    yield
  ensure
    Discovery.define_singleton_method(:search, original)
  end

  def example_for(documents)
    with_documents(documents) { ExploreEntryPoints.send(:example_image, "collection_ssim:\"Grainger Museum Collection\"") }
  end

  test "the first open, non-sensitive record is chosen, with its file's size" do
    image = example_for([ doc("a", "licence_type_ssim" => [ "ICIP Rights" ]), doc("b", "restrictions_tsi" => [ "Culturally sensitive" ]), doc("c", "licence_type_ssim" => [ "Copyright - Current" ]), doc("d") ])

    assert_equal "d", image[:id]
    assert_equal PATH, image[:path]
    assert_operator image[:width], :>, 0
  end

  test "no image when no record may be shown, or its file is not held here" do
    assert_nil example_for([ doc("a", "licence_type_ssim" => [ "ICIP Rights" ]) ])
    assert_nil example_for([ doc("a", "thumbnail_path_ssi" => "https://example.org/x.jpg") ])
    assert_nil example_for([ doc("a", "thumbnail_path_ssi" => "/digital-assets/thumbs/missing.jpg") ])
  end

  test "tiles carry the kept image, and a tile without one has none" do
    counts = { "collections" => [ [ "Grainger Museum Collection", 3 ], [ "Medical History Museum", 2 ] ], "kinds" => [], "places" => [], "periods" => {},
               "images" => { "Grainger Museum Collection" => { id: "d", title: "Record d", path: PATH, width: 10, height: 10 } } }

    tiles = ExploreEntryPoints.overview(counts).collections

    assert_equal "d", tiles.first.image.id
    assert_nil tiles.last.image
  end

  test "a kept image of the Indigenous Collections tile is never used, and none is looked for" do
    counts = { "collections" => [ [ "Indigenous Collections", 3 ] ], "kinds" => [], "places" => [], "periods" => {},
               "images" => { "Indigenous Collections" => { id: "d", title: "Record d", path: PATH, width: 10, height: 10 } } }

    assert_nil ExploreEntryPoints.overview(counts).collections.first.image

    asked = []
    response = Struct.new(:documents).new([])
    original = Discovery.method(:search)
    Discovery.define_singleton_method(:search) { |params| asked << params[:fq].last && response }
    begin
      ExploreEntryPoints.send(:fetch_images, [ [ "Indigenous Collections", 3 ], [ "Medical History Museum", 2 ] ])
    ensure
      Discovery.define_singleton_method(:search, original)
    end
    assert_equal 1, asked.size
    assert_match(/Medical History Museum/, asked.first)
  end
end
