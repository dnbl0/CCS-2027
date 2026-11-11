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

    assert_selector "[data-controller=deep-zoom] button[aria-pressed=false][hidden]", text: "Zoom and pan", visible: :all
    sources = JSON.parse(page.find("[data-controller=deep-zoom]", visible: :all)["data-deep-zoom-sources-value"])
    assert_equal [ "/digital-assets/large/a.jpg", "/digital-assets/large/b.jpg" ], sources.map { |source| source["url"] }
    assert_equal "https://iiif.example.org/a/info.json", sources.first["info"]
    assert_equal "A portrait, image 1 of 2", sources.first["alt"]
    %w[Zoom\ in Zoom\ out Reset\ view].each { |name| assert_selector ".deep-zoom__controls button", text: name, visible: :all }
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
end
