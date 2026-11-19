require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

# The media in the approved split layout (Figma "Object viewer"): the controls row under the picture (licence and access chips, round
# tools), the thumbnail strip, and the media metadata the record column's "Media details" section lists
class MediaSectionTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  Presenter = Struct.new(:document)

  def page = Capybara::Node::Simple.new(rendered_content)

  def component(fields) = NexusCcs::DigitalAssetsComponent.new(presenter: Presenter.new(SolrDocument.new(fields)))

  def render_for(fields) = render_inline(component(fields))

  FIELDS = {
    "title_tsim" => [ "Kangaroo Pouch" ],
    "digital_asset_paths_ssim" => [ "/digital-assets/thumbs/a.jpg" ],
    "digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg" ],
    "licence_type_ssim" => [ "In copyright" ],
    "rights_ssim" => [ "[In copyright] WARNING This material is All Rights Reserved." ]
  }.freeze

  test "the controls row has the licence chip and round zoom and full screen tools, hidden until the script can work them" do
    render_for(FIELDS)

    assert_selector ".digital-assets__controls-row .viewer-chip", text: "In copyright"
    assert_selector ".digital-assets__tools[role=group][aria-label='Image tools']"
    %w[Zoom\ in Zoom\ out Full\ screen].each do |name|
      assert_selector "button.viewer-control[hidden]", text: name, visible: :all
    end
    assert_no_selector "button[aria-controls=media-metadata]" # the metadata is the record column's Media details section
  end

  test "the media metadata lists licence type, advisory and terms of use, without the licence name in brackets" do
    rows = component(FIELDS).metadata

    assert_equal [ "Licence type", "Advisory", "Terms of use" ], rows.map(&:first)
    assert_includes rows.to_h["Terms of use"], "WARNING This material is All Rights Reserved."
    assert_not_includes rows.to_h["Terms of use"], "[In copyright]"
  end

  test "a record with no licence still has the advisory and no licence chip" do
    render_for(FIELDS.except("licence_type_ssim", "rights_ssim"))

    assert_no_selector ".viewer-chip svg" # the licence chip is the one with the Creative Commons mark
    assert_includes component(FIELDS.except("licence_type_ssim", "rights_ssim")).metadata.to_h["Advisory"], "not appropriate today"
  end

  test "a producer is the metadata's last row; absent, it just does not appear" do
    rows = component(FIELDS.merge("producer_ssim" => [ "Nexus Digitisation Studio" ])).metadata

    assert_equal [ "Licence type", "Advisory", "Terms of use", "Producer" ], rows.map(&:first)
    assert_equal "Nexus Digitisation Studio", rows.to_h["Producer"]
    assert_not_includes component(FIELDS).metadata.map(&:first), "Producer"
  end

  test "glyphs are inlined in the text colour" do
    html = render_for(FIELDS).to_html

    assert_includes html, 'stroke="currentColor"'
    assert_not_includes html, "#000F46"
  end
end
