require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

require_relative "../../support/dam_fakes"

class DigitalAssetsComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions
  include DamFakes

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

  test "the media metadata (the record column's Media details) is the DAM's licence, advisory, terms of use and producer" do
    dam = { "licence" => "All Rights reserved (UoM)", "advisory" => "Sensitivity", "terms_of_use" => "Ask the Grainger Museum",
            "producer" => "Lee McRae (Photographer)" }
    fields = assets(1).merge("digital_asset_metadata_ssm" => [ dam.to_json ], "rights_ssim" => [ "EMu note" ])
    rows = NexusCcs::DigitalAssetsComponent.new(presenter: Presenter.new(SolrDocument.new(fields))).metadata.to_h

    assert_equal({ "Licence type" => dam["licence"], "Advisory" => dam["advisory"], "Terms of use" => dam["terms_of_use"], "Producer" => dam["producer"] }, rows)
    render_for(fields)
    assert_not_includes rendered_content, "EMu note"
    assert_not_includes rendered_content, "Public domain - Copyright expired"
  end

  test "a single asset is one large image named for the record" do
    render_for(assets(1))

    assert_selector "section.digital-assets h2.visually-hidden", text: "Digital asset", exact_text: true
    assert_selector "figure.digital-assets__main img[src='/digital-assets/large/a1.jpg'][alt='Cary Pocket microscope']"
    assert_no_selector ".digital-assets__thumbs"
  end

  test "several assets: the first is large, and a strip of every thumbnail (the first marked) swaps the large image" do
    render_for(assets(3))

    assert_selector "h2", text: "Digital assets"
    assert_selector "figure img[alt='Cary Pocket microscope, image 1 of 3']"
    assert_selector "div.digital-assets__strip[role=group][aria-label='All images of this record'] .digital-assets__thumbs li", count: 3
    assert_selector "a.digital-assets__thumb[aria-current=true][href='/digital-assets/large/a1.jpg']"
    assert_selector "a.digital-assets__thumb[href='/digital-assets/large/a2.jpg'][target=_blank][rel=noopener][aria-label='Show image 2 of 3'] img[src='/digital-assets/thumbs/a2.jpg'][alt='']"
    assert_selector "button.viewer-control--ghost[hidden]", text: "Previous image", visible: :all
    assert_selector "button.viewer-control--ghost[hidden]", text: "Next image", visible: :all
  end

  test "an open record has no notice, and its media can be downloaded" do
    render_for(assets(3).merge("digital_media_ssim" => [ "video|video/mp4|/v.mp4|Film", "pdf|application/pdf|/d.pdf|Report" ]))

    assert_no_selector ".access-notice"
    assert_selector "video:not([controlslist])"
    assert_selector "video a[href='/v.mp4']", text: "Download Film"
    assert_selector "a.digital-assets__pdf[href='/d.pdf']"
  end

  # The DAM holds videos as WMV, which no web browser plays: a player would stay blank (seen 2026-11-18)
  test "a video in a format browsers cannot play says so, and an open one offers the file to download instead" do
    render_for(assets(3).merge("digital_media_ssim" => [ "video|video/x-ms-wmv|/v.wmv|Film" ]))

    assert_no_selector "video"
    assert_selector ".digital-assets__unplayable", text: "This video is in a format (WMV) that web browsers cannot play."
    assert_selector ".digital-assets__unplayable a[href='/v.wmv']", text: "Download Film (WMV)"
  end

  test "a view-only video browsers cannot play offers a request for a copy, never the file" do
    render_for(assets(3).merge("licence_type_ssim" => [ "Copyright - Current" ], "digital_media_ssim" => [ "video|video/x-ms-wmv|/v.wmv|Film" ]))

    assert_no_selector "video, a[href='/v.wmv']"
    assert_selector ".digital-assets__unplayable a[href^='/access_requests/new']", text: "Ask the collection team for a copy of Film"
  end

  test "the unplayable link takes the media band's light text, as specific as the site's ID-scoped link rule" do
    css = Rails.root.join("app/assets/stylesheets/components/media_viewer.css").read
    assert_match(/:is\(main, #main-container\) \.digital-assets__unplayable a \{[^}]*color: inherit;/, css)
  end

  test "a file whose only title is its file name is called 'this video' in the links" do
    render_for(assets(3).merge("digital_media_ssim" => [ "video|video/x-ms-wmv|/v.wmv|item395-processed.wmv" ]))

    assert_selector ".digital-assets__unplayable a[href='/v.wmv']", text: "Download this video (WMV)"
  end

  test "a video browsers can play keeps its player" do
    render_for(assets(3).merge("digital_media_ssim" => [ "video|video/mp4|/v.mp4|Film", "audio|audio/x-wav|/a.wav|Interview" ]))

    assert_selector "video source[src='/v.mp4']"
    assert_selector "audio source[src='/a.wav']"
    assert_no_selector ".digital-assets__unplayable"
  end

  test "a view-only record shows the viewer and a notice, with nothing that downloads" do
    render_for(assets(3).merge("licence_type_ssim" => [ "Copyright - Current" ],
                               "digital_media_ssim" => [ "video|video/mp4|/v.mp4|Film", "pdf|application/pdf|/d.pdf|Report" ]))

    assert_no_selector ".access-notice" # the notice is in the actions column (RecordActionsComponent)
    assert_selector ".viewer-chip--view-only", text: "View only"
    assert_no_selector "a[download]"
    assert_selector "figure.digital-assets__main img[src='/digital-assets/large/a1.jpg']"
    assert_selector "video[controlslist=nodownload]"
    assert_no_selector "video a, a[href='/v.mp4'], a[href='/d.pdf'], .digital-assets__pdf"
    assert_no_selector "a[href*='/digital-assets/']" # thumbnails are buttons, not links to the files
    assert_selector "button.digital-assets__thumb[data-media-viewer-large='/digital-assets/large/a2.jpg'] img[alt='']"
    assert_selector ".viewer-chip", text: "Copyright - Current"
  end

  test "a request record withholds every asset, and its path, but keeps the notice, licence and metadata" do
    render_for(assets(3).merge("licence_type_ssim" => [ "ICIP Rights" ], "digital_media_ssim" => [ "video|video/mp4|/v.mp4|Film" ]))

    assert_selector ".access-notice--request", text: "This item is available on request"
    assert_selector ".access-notice a", text: "Request access to this item"
    assert_no_selector "img, video, audio, figure, .digital-assets__thumbs, [data-media-viewer-target=image]"
    assert_no_selector "button", text: "Full screen", visible: :all
    assert_selector ".viewer-chip", text: "ICIP Rights"
    assert_selector ".viewer-chip--request", text: "Available on request"
    %w[/digital-assets /v.mp4 a1.jpg].each { |path| assert_not_includes rendered_content, path }
  end

  # Per-asset licences: the record as the DAM sync writes it (Dam::SolrWriter), from DAM assets with their own licences
  def dam_record(licences, emu: {})
    licences.each_with_index do |(id, licence, format), index|
      DamAsset.create!(DamAsset.attributes_from_api(dam_item(id, format: format || "image")).merge(licence: licence, display_sequence: index + 1))
    end
    assets = DamAsset.live.in_display_order.to_a
    fields = Dam::SolrWriter.fields_for(assets, { "id" => "emu-1" }.merge(emu)).compact
    { "id" => "emu-1", "title_tsim" => [ "Cary Pocket microscope" ] }.merge(emu).merge(fields)
  end

  def dam_url(id, size = "large") = "https://unimelbourne.widen.net/content/#{id}/jpeg/#{size}.jpg"

  test "a record with a licensed and an unlicensed image shows the licensed one only, and no address of the other" do
    render_for(dam_record([ [ "unlicensed", "None" ], [ "licensed", "CC BY" ] ]))

    assert_selector "figure.digital-assets__main img[src^='#{dam_url('licensed')}'][alt='Cary Pocket microscope']"
    assert_no_selector ".digital-assets__thumbs"
    assert_not_includes rendered_content, "/content/unlicensed/"
    assert_selector ".access-notice--partly-withheld", text: "1 other digital asset of this record is not shown"
    assert_selector ".access-notice--partly-withheld a[href='/access_requests/new?document_id=emu-1']", text: "Request access to it"
    assert_selector ".digital-assets__download a.btn[download][href^='#{dam_url('licensed')}']", visible: :all
    assert_selector ".viewer-chip", text: "CC BY" # the shown asset's licence, not the withheld one's "None"
  end

  test "only open assets are offered to download: a view-only image is a button, an open one a link" do
    render_for(dam_record([ [ "open", "CC BY" ], [ "view", "Individual" ], [ "open2", "CC0" ] ]))

    assert_selector ".digital-assets__download a.btn[download][href^='#{dam_url('open')}']", visible: :all
    assert_selector "button.digital-assets__thumb[data-media-viewer-large^='#{dam_url('view')}']"
    assert_no_selector "a[href^='#{dam_url('view')}']"
    assert_selector "a.digital-assets__thumb[href^='#{dam_url('open2')}']"
    assert_no_selector ".access-notice"
  end

  test "a first image that is view only has no download button, even when the record has an open one" do
    render_for(dam_record([ [ "view", "Individual" ], [ "open", "CC BY" ] ]))

    assert_selector "figure.digital-assets__main img[src^='#{dam_url('view')}']"
    assert_no_selector "a[download]"
    assert_selector "a.digital-assets__thumb[href^='#{dam_url('open')}']"
  end

  test "media files follow their own licence: an open film can be downloaded, a view-only PDF is left out" do
    render_for(dam_record([ [ "img", "CC BY" ], [ "film", "CC BY", "video" ], [ "doc", "Individual", "pdf" ], [ "talk", "Individual", "audio" ] ]))

    assert_selector "video:not([controlslist])"
    assert_selector "video a", text: /Download/
    assert_selector "audio[controlslist=nodownload]"
    assert_no_selector "audio a"
    assert_no_selector ".digital-assets__pdf"
  end

  test "an ICIP record shows none of its assets, whatever their DAM licences" do
    render_for(dam_record([ [ "a", "CC BY" ], [ "b", "Individual" ] ], emu: { "licence_type_ssim" => [ "ICIP Rights" ] }))

    assert_selector ".access-notice--request"
    assert_no_selector "img, .access-notice--partly-withheld"
    assert_not_includes rendered_content, "unimelbourne.widen.net"
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
