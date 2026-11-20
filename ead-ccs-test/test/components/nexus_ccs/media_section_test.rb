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

  test "the controls bar has named rotate, zoom and full screen controls, hidden until the script can work them; the licence chip is under the viewer" do
    render_for(FIELDS)

    assert_selector ".media-viewer__caption .viewer-chip", text: "In copyright"
    assert_selector ".media-viewer__bar[role=group][aria-label='Image tools']"
    %w[Rotate\ left Rotate\ right Zoom\ in Reset\ zoom\ and\ rotation Zoom\ out].each do |name|
      assert_selector "[hidden] button.viewer-control[aria-label='#{name}'][title]", visible: :all
    end
    assert_selector "[hidden] button.viewer-control[aria-label='Full screen'][aria-pressed=false]", visible: :all
    # at fit, Reset and Zoom out start unavailable (aria-disabled, still focusable)
    assert_selector "button[aria-label='Zoom out'][aria-disabled=true]", visible: :all
    assert_no_selector ".media-viewer__readout", visible: true # the zoom readout only while zoomed
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
    assert_selector "a.viewer-chip--link[href='#use-and-access']", text: "Use this image" # without a licence, a plain way to the panel
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
