# frozen_string_literal: true

require "test_helper"

# The example picture of each Explore group: only a record whose asset anyone may download and that is not sensitive (AccessPolicy, Sensitivity)
class ExploreEntryPointsImagesTest < ActiveSupport::TestCase
  PATH = "/digital-assets/thumbs/0000_013_1_pf.jpg"

  def doc(id, fields = {})
    SolrDocument.new({ "id" => id, "title_tsim" => [ "Record #{id}" ], "thumbnail_path_ssi" => PATH, "licence_type_ssim" => [ "Public domain - Copyright expired" ] }.merge(fields))
  end

  def example_for(documents)
    response = Struct.new(:documents).new(documents)
    original = Discovery.method(:search)
    Discovery.define_singleton_method(:search) { |_params| response }
    ExploreEntryPoints.send(:example_image, "object_type_ssim:(\"lyre\")")
  ensure
    Discovery.define_singleton_method(:search, original)
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

  test "groups carry the kept image, and a group without one has none" do
    counts = { "object_type_ssim" => [ [ "lyre", 3 ] ], "production_place_ssim" => [ [ "Japan", 2 ] ], "periods" => {},
               "images" => { "object-type" => { id: "d", title: "Record d", path: PATH, width: 10, height: 10 } } }

    groups = ExploreEntryPoints.groups(counts)

    assert_equal "d", groups.first.image.id
    assert_nil groups.last.image
  end
end
