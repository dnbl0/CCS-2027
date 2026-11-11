require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

class DigitalAssetsComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  Presenter = Struct.new(:document)

  def page = Capybara::Node::Simple.new(rendered_content)

  def render_for(fields)
    render_inline(NexusCcs::DigitalAssetsComponent.new(presenter: Presenter.new(SolrDocument.new(fields))))
  end

  def assets(count)
    names = (1..count).map { |n| "a#{n}.jpg" }
    {
      "title_tsim" => [ "Cary Pocket microscope" ],
      "licence_type_ssim" => [ "Public domain - Copyright expired" ],
      "digital_asset_paths_ssim" => names.map { |n| "/digital-assets/thumbs/#{n}" },
      "digital_asset_large_paths_ssim" => names.map { |n| "/digital-assets/large/#{n}" }
    }
  end

  test "a single asset is one large image named for the record" do
    render_for(assets(1))

    assert_selector "section.digital-assets[aria-labelledby=digital-assets-heading] #digital-assets-heading.visually-hidden", text: "Digital asset", exact_text: true
    assert_no_selector "section.digital-assets h2, section.digital-assets h3" # nothing before the page's h1 is a heading
    assert_selector "figure.digital-assets__main img[src='/digital-assets/large/a1.jpg'][alt='Cary Pocket microscope']"
    assert_no_selector ".digital-assets__others"
  end

  test "several assets: the first is large and every one is in the strip under it, the first as the current one, each opening the large image" do
    render_for(assets(3))

    assert_selector "#digital-assets-heading", text: "Digital assets"
    assert_selector "figure img[alt='Cary Pocket microscope, image 1 of 3']"
    assert_selector ".digital-assets__others li", count: 3
    assert_selector ".digital-assets__others a.digital-assets__other.is-current[aria-current=true][href='/digital-assets/large/a1.jpg']"
    assert_selector "a.digital-assets__other[href='/digital-assets/large/a2.jpg'][target=_blank][rel=noopener] img[src='/digital-assets/thumbs/a2.jpg']"
    assert_selector "a img[alt='Cary Pocket microscope, image 3 of 3 (opens full size in a new tab)']"
  end

  test "an open record has no notice, and its media can be downloaded" do
    render_for(assets(3).merge("digital_media_ssim" => [ "video|video/mp4|/v.mp4|Film", "pdf|application/pdf|/d.pdf|Report" ]))

    assert_no_selector ".access-notice"
    assert_selector "video:not([controlslist])"
    assert_selector "video a[href='/v.mp4']", text: "Download Film"
    assert_selector "a.digital-assets__pdf[href='/d.pdf']"
  end

  test "a view-only record shows the viewer and a notice, with nothing that downloads" do
    render_for(assets(3).merge("licence_type_ssim" => [ "Copyright - Current" ],
                               "digital_media_ssim" => [ "video|video/mp4|/v.mp4|Film", "pdf|application/pdf|/d.pdf|Report" ]))

    assert_no_selector ".access-notice" # the notice is in the actions column (RecordActionsComponent)
    assert_selector ".digital-assets__access--view-only", text: "View only"
    assert_no_selector ".digital-assets__primary, a[download]"
    assert_selector "figure.digital-assets__main img[src='/digital-assets/large/a1.jpg']"
    assert_selector "video[controlslist=nodownload]"
    assert_no_selector "video a, a[href='/v.mp4'], a[href='/d.pdf'], .digital-assets__pdf"
    assert_no_selector "a[href*='/digital-assets/']" # thumbnails are buttons, not links to the files
    assert_selector "button.digital-assets__other[data-media-viewer-large='/digital-assets/large/a2.jpg'] img[alt='Cary Pocket microscope, image 2 of 3']"
    assert_selector ".digital-assets__licence", text: "Copyright - Current"
  end

  test "a request record withholds every asset, and its path, but keeps the notice, licence and metadata" do
    render_for(assets(3).merge("licence_type_ssim" => [ "ICIP Rights" ], "digital_media_ssim" => [ "video|video/mp4|/v.mp4|Film" ]))

    assert_selector ".access-notice--request", text: "This item is available on request"
    assert_selector ".access-notice a", text: "Request access to this item"
    assert_no_selector "img, video, audio, figure, .digital-assets__others, [data-media-viewer-target=image]"
    assert_no_selector "button", text: "Full screen", visible: :all
    assert_selector ".digital-assets__licence", text: "ICIP Rights"
    assert_selector "button[aria-controls=media-metadata]", text: "Media information"
    assert_selector ".digital-assets__access--request", text: "Available on request"
    %w[/digital-assets /v.mp4 a1.jpg].each { |path| assert_not_includes rendered_content, path }
  end

  test "a record without assets renders nothing" do
    render_for("title_tsim" => [ "No images here" ])
    assert_no_selector ".digital-assets"
  end

  test "the show page's embed component wraps it with the record summary" do
    assert_equal NexusCcs::RecordEmbedComponent, CatalogController.blacklight_config.view_config(:show).document_embed_component
  end

  # CCS-227: a sensitive record's assets wait for the visitor's choice
  SENSITIVE = { "id" => "emu-9", "restrictions_tsi" => "Not for publishing Sensitive|Culturally sensitive images" }.freeze

  test "a sensitive record shows the notice and none of the asset until the visitor chooses to view it" do
    render_for(assets(3).merge(SENSITIVE).merge("digital_media_ssim" => [ "video|video/mp4|/v.mp4|Film" ]))

    assert_selector ".sensitivity-gate--ask button", text: "View this item"
    assert_selector ".sensitivity-gate--ask button", text: "Do not view"
    assert_no_selector "img"
    assert_no_selector "video"
    assert_no_selector "button", text: "Full screen", visible: :all, visible: :all
    assert_not_includes rendered_content, "/digital-assets/"
    assert_not_includes rendered_content, "/v.mp4"
  end

  test "a sensitive record that is withheld stays withheld: the request notice, no choice to view" do
    render_for(assets(1).merge(SENSITIVE).merge("licence_type_ssim" => [ "ICIP Rights" ]))

    assert_selector ".access-notice--request"
    assert_no_selector ".sensitivity-gate"
    assert_no_selector "img"
  end

  test "a record that is not sensitive is shown as before, with no notice" do
    render_for(assets(1))

    assert_no_selector ".sensitivity-gate"
    assert_selector "img.digital-assets__image"
  end
end
