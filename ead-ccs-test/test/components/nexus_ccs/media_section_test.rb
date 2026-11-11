require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

# The media section after the CCS UI "Record-detail" (Figma 258:25197): band, Media metadata panel, toolbar
class MediaSectionTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  Presenter = Struct.new(:document)

  def page = Capybara::Node::Simple.new(rendered_content)

  def render_for(fields)
    render_inline(NexusCcs::DigitalAssetsComponent.new(presenter: Presenter.new(SolrDocument.new(fields))))
  end

  FIELDS = {
    "title_tsim" => [ "Kangaroo Pouch" ],
    "digital_asset_paths_ssim" => [ "/digital-assets/thumbs/a.jpg" ],
    "digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg" ],
    "licence_type_ssim" => [ "In copyright" ],
    "rights_ssim" => [ "[In copyright] WARNING This material is All Rights Reserved." ]
  }.freeze

  test "the toolbar has the licence chip, the metadata button and the full screen button" do
    render_for(FIELDS)

    assert_selector ".digital-assets__toolbar .digital-assets__licence", text: "In copyright"
    assert_selector "button[aria-controls=media-metadata][aria-expanded=false]", text: "Media information"
    assert_selector "button[hidden]", text: "Full screen", visible: :all
  end

  test "the metadata panel is closed until opened, with licence type, advisory and terms of use" do
    render_for(FIELDS)

    assert_selector "aside#media-metadata[aria-hidden=true]:not(.is-open)", visible: :all
    panel = page.find("aside#media-metadata", visible: :all)
    assert_equal [ "Licence type", "Advisory", "Terms of use" ], panel.all("dt", visible: :all).map(&:text).map(&:strip).then { |t| t.empty? ? panel.all("dt", visible: :all).map { |n| n.text(:all).strip } : t }
    assert_includes panel.text(:all), "WARNING This material is All Rights Reserved."
    assert_not_includes panel.text(:all), "[In copyright]"
  end

  test "a record with no licence still has the advisory panel and no licence chip" do
    render_for(FIELDS.except("licence_type_ssim", "rights_ssim"))

    assert_no_selector ".digital-assets__licence"
    assert_includes page.find("aside#media-metadata", visible: :all).text(:all), "not appropriate today"
  end

  test "a producer shows as the panel's last row; absent, it just does not appear" do
    render_for(FIELDS.merge("producer_ssim" => [ "Nexus Digitisation Studio" ]))
    panel = page.find("aside#media-metadata", visible: :all)

    assert_equal [ "Licence type", "Advisory", "Terms of use", "Producer" ], panel.all("dt", visible: :all).map { |n| n.text(:all).strip }
    assert_includes panel.text(:all), "Nexus Digitisation Studio"

    render_for(FIELDS)
    assert_not_includes page.find("aside#media-metadata", visible: :all).text(:all), "Producer"
  end

  test "icons are inlined in the text colour" do
    html = render_for(FIELDS).to_html

    assert_includes html, 'stroke="currentColor"'
    assert_not_includes html, "#000F46"
  end
end
