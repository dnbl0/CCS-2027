require "test_helper"

# CCS-57: the registry that says how each kind of file is shown
class MediaTypesTest < ActiveSupport::TestCase
  test "the DAM's format types map to a kind and a viewer partial" do
    { "image" => :image, "Video" => :video, "AUDIO" => :audio, "pdf" => :pdf }.each do |format_type, kind|
      type = MediaTypes.for(format_type: format_type)
      assert_equal kind, type.kind, format_type
      assert type.previewable?, format_type
      assert_equal MediaTypes::VIEWERS.fetch(kind), type.viewer
    end
  end

  test "a file with no format type is told by its MIME type, then its extension" do
    assert_equal :video, MediaTypes.for(mime: "video/mp4").kind
    assert_equal :pdf, MediaTypes.for(filename: "/media/Report.PDF").kind
    assert_equal :image, MediaTypes.for(mime: "application/octet-stream", filename: "x.tiff").kind
  end

  test "3D models are known but have no viewer yet, so they are not previewable" do
    %w[3d model].each { |format_type| assert_equal :model_3d, MediaTypes.for(format_type: format_type).kind }
    %w[a.glb a.gltf a.obj a.usdz].each { |name| assert_equal :model_3d, MediaTypes.for(filename: name).kind, name }
    assert_equal :model_3d, MediaTypes.for(mime: "model/gltf-binary").kind
    type = MediaTypes.for(format_type: "3d")
    assert_not type.previewable?
    assert_nil type.viewer
    assert_equal "3D model", type.label
  end

  test "an unknown file is :other, and a kind without a viewer is given the cannot-be-previewed partial" do
    assert_equal :other, MediaTypes.for(format_type: "spreadsheet").kind
    assert_equal :other, MediaTypes.for.kind
    assert_equal MediaTypes::UNSUPPORTED_VIEWER, MediaTypes.viewer_for(:model_3d)
    assert_equal MediaTypes::UNSUPPORTED_VIEWER, MediaTypes.viewer_for("other")
    assert_equal "media_viewers/video", MediaTypes.viewer_for("video")
  end

  test "the viewer partials the registry names exist" do
    (MediaTypes::VIEWERS.values + [ MediaTypes::UNSUPPORTED_VIEWER ]).each do |partial|
      dir, name = partial.split("/")
      assert Rails.root.join("app/views/#{dir}/_#{name}.html.erb").exist?, partial
    end
  end

  test "the IIIF field is named in one place" do
    assert_equal "iiif_info_urls_ssim", MediaTypes::IIIF_INFO_FIELD
  end
end
