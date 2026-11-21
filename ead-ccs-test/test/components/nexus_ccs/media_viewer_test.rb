require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

# CCS-57, CCS-58: the zoom viewer's and compare actions' markup on the record page, per access tier. Neither may put an image
# address in the page for a record whose images are not being shown.
class MediaViewerComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  Presenter = Struct.new(:document)

  def page = Capybara::Node::Simple.new(rendered_content)

  def render_for(fields)
    fields = { "id" => "emu-1", "title_tsim" => [ "A portrait" ], "licence_type_ssim" => [ "Public domain - Copyright expired" ],
               "digital_asset_paths_ssim" => [ "/digital-assets/thumbs/a.jpg", "/digital-assets/thumbs/b.jpg" ],
               "digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg", "/digital-assets/large/b.jpg" ] }.merge(fields)
    render_inline(NexusCcs::DigitalAssetsComponent.new(presenter: Presenter.new(SolrDocument.new(fields))))
  end

  test "an open record offers zoom and pan, with the image sources the viewer may open, and compare" do
    render_for({ MediaTypes::IIIF_INFO_FIELD => [ "https://iiif.example.org/a/info.json", "" ] })

    # Zoom opens the modal; its zoom, rotate and reset controls drive the viewer (media-viewer:zoom)
    assert_selector "button.round-control[hidden][aria-haspopup=dialog][data-action='media-viewer#openZoom']", visible: :all
    assert_selector "[data-controller=deep-zoom][data-action*='media-viewer:zoom@window->deep-zoom#zoom']", visible: :all
    sources = JSON.parse(page.find("[data-controller=deep-zoom]", visible: :all)["data-deep-zoom-sources-value"])
    assert_equal [ "/digital-assets/large/a.jpg", "/digital-assets/large/b.jpg" ], sources.map { |source| source["url"] }
    assert_equal "https://iiif.example.org/a/info.json", sources.first["info"]
    assert_equal "A portrait, image 1 of 2", sources.first["alt"]
    { "Zoom in" => "zoomIn", "Zoom out" => "zoomOut", "Reset zoom and rotation" => "reset", "Rotate" => "rotateRight" }.each do |name, action|
      assert_selector "dialog.media-zoom .media-zoom__tools button[aria-label='#{name}'][data-action='media-viewer##{action}']", visible: :all
    end
    assert_no_selector ".compare-actions" # Compare is in the actions column (RecordActionsComponent)
  end

  test "a withheld record offers neither, and has no image address in the page" do
    render_for("licence_type_ssim" => [ "ICIP Rights" ])

    assert_no_selector ".deep-zoom", visible: :all
    assert_no_selector ".compare-actions", visible: :all
    assert_not_includes rendered_content, "/digital-assets/"
  end

  test "a view-only record offers both, and no link to the file" do
    render_for("licence_type_ssim" => [ "Copyright - Current" ])

    assert_selector ".deep-zoom", visible: :all
    assert_no_selector "a[href='/digital-assets/large/b.jpg']"
  end

  test "a sensitive record has none of it until the visitor has chosen to view it" do
    render_for("restrictions_tsi" => [ "Culturally sensitive images" ])

    assert_no_selector ".deep-zoom", visible: :all
    assert_no_selector ".compare-actions", visible: :all
    assert_not_includes rendered_content, "/digital-assets/"
  end

  test "a file with no viewer says it cannot be previewed, and offers the file only where it may be downloaded" do
    media = { "digital_media_ssim" => [ "model|model/gltf-binary|/m/skull.glb|Skull scan" ] }
    render_for(media)
    assert_selector ".digital-assets__unsupported", text: /3d model cannot be previewed here/i
    assert_selector ".digital-assets__unsupported a[href='/m/skull.glb']", text: "Download Skull scan"

    render_for(media.merge("licence_type_ssim" => [ "Copyright - Current" ]))
    assert_no_selector "a[href='/m/skull.glb']"
  end

  test "captions and a transcript are offered when the record has them" do
    render_for("digital_media_ssim" => [ "video|video/mp4|/v.mp4|Film|/v.vtt|/v.html" ])

    assert_selector "video track[kind=captions][src='/v.vtt'][srclang=en]", visible: :all
    assert_selector ".digital-assets__transcript a[href='/v.html'][target=_blank]", text: /Transcript of Film/
  end

  DAM_LARGE = "https://unimelbourne.widen.net/content/abc123/jpeg/portrait.jpg?w=2000".freeze

  test "a DAM image opens in the zoom viewer as a plain image, at its own address (no IIIF info.json needed)" do
    render_for("digital_asset_large_paths_ssim" => [ DAM_LARGE ], "digital_asset_paths_ssim" => [ DAM_LARGE ])

    sources = JSON.parse(page.find("[data-controller=deep-zoom]", visible: :all)["data-deep-zoom-sources-value"])
    assert_equal [ DAM_LARGE ], sources.map { |source| source["url"] }
    assert_nil sources.first["info"]
  end

  test "DAM audio and video play inline from their own address; a type the browser cannot use is left for it to work out" do
    render_for("digital_media_ssim" => [ "audio|audio/mpeg|https://unimelbourne.widen.net/content/a1/original/song.mp3|song.mp3",
                                         "video|application/octet-stream|https://unimelbourne.widen.net/content/v1/original/film|film" ])

    assert_selector "audio[controls] source[src='https://unimelbourne.widen.net/content/a1/original/song.mp3'][type='audio/mpeg']", visible: :all
    assert_selector "video[controls] source[src='https://unimelbourne.widen.net/content/v1/original/film']", visible: :all
    assert_no_selector "video source[type]", visible: :all
  end
end
