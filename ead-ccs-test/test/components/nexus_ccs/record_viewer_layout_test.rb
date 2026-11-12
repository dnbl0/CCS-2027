require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

# The viewer layout of a record page (?layout=viewer): the viewer (three round controls, a dark strip with Previous, thumbnails, Next and
# "Use this image"), the access rules in markup (no asset path for a withheld or not-yet-chosen sensitive record, no download link for a
# view-only one), and the data panel and its bar.
class RecordViewerLayoutTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  Presenter = Struct.new(:document)

  def page = Capybara::Node::Simple.new(rendered_content)

  FIELDS = { "id" => "emu-1", "title_tsim" => [ "Kangaroo-pouch tone-tool" ], "description_tsim" => [ "A tool for tone." ], "collection_ssim" => [ "University Art Collection" ] }.freeze
  IMAGES = { "digital_asset_paths_ssim" => %w[/digital-assets/thumbs/a.jpg /digital-assets/thumbs/b.jpg /digital-assets/thumbs/c.jpg],
             "digital_asset_large_paths_ssim" => %w[/digital-assets/large/a.jpg /digital-assets/large/b.jpg /digital-assets/large/c.jpg] }.freeze

  def doc(extra = {}) = SolrDocument.new(FIELDS.merge(extra))

  def render_media(extra = {}) = render_inline(NexusCcs::ViewerMediaComponent.new(presenter: Presenter.new(doc(extra))))

  test "the viewer has three round buttons, each named (zoom in, zoom out, full view), a dark strip with Previous, a named thumbnail each and Next" do
    render_media(IMAGES.merge("licence_type_ssim" => [ "Copyright - Current" ]))

    assert_selector ".viewer-pill[role=group] button.viewer-pill__button", count: 3, visible: :all
    [ "Zoom in", "Zoom out", "Full view" ].each { |name| assert_selector ".viewer-pill button[aria-label='#{name}']", visible: :all }
    assert_selector ".viewer-pill button[disabled][aria-label='Zoom out']", visible: :all # nothing to zoom out of until the viewer is on
    assert_selector ".viewer-strip button[aria-label='Previous image'][disabled]"
    assert_selector ".viewer-strip button[aria-label='Next image']:not([disabled])"
    assert_selector ".viewer-strip__thumbs li", count: 3
    assert_selector ".viewer-media__thumb[aria-label='Display image 2 of 3']"
    assert_selector ".viewer-media__thumb.is-current[aria-current=true]", count: 1
    assert_selector "[role=status][data-media-viewer-target=counter]", text: "Image 1 of 3", visible: :all
    assert_no_selector "[data-deep-zoom-target=toggle]", visible: :all # no toggle: the viewer starts on its own
    assert_selector "#viewer-description.visually-hidden", text: "A tool for tone.", visible: :all
  end

  test "Use this image: an open record downloads the current image, a view-only record goes to its rights, a withheld one asks, and none has another path" do
    render_media(IMAGES.merge("licence_type_ssim" => [ "Public domain - Copyright expired" ]))
    assert_selector ".viewer-strip a.viewer-strip__use[download][href='/digital-assets/large/a.jpg'][data-media-viewer-target=use]", text: "Use this image"

    render_media(IMAGES.merge("licence_type_ssim" => [ "Copyright - Current" ]))
    assert_selector ".viewer-strip a.viewer-strip__use[href='#viewer-rights']", text: "Use this image"
    assert_no_selector "a[download], a[href*='/digital-assets/']"

    render_media(IMAGES.merge("licence_type_ssim" => [ "ICIP Rights" ]))
    assert_selector ".viewer-strip a.viewer-strip__use[href='/access_requests/new?document_id=emu-1']"
    assert_not_includes rendered_content, "/digital-assets/"
  end

  test "a request-only or not-yet-chosen sensitive record has no asset address in the viewer, and the notice is inside the stage" do
    render_media(IMAGES.merge("licence_type_ssim" => [ "ICIP Rights" ]))
    assert_selector ".viewer-media__stage .viewer-media__picture .access-notice--request"
    assert_not_includes rendered_content, "/digital-assets/"

    render_media(IMAGES.merge("restrictions_tsi" => [ "Culturally sensitive images" ]))
    assert_selector ".viewer-media__stage .viewer-media__picture .sensitivity-gate"
    assert_not_includes rendered_content, "/digital-assets/"
    assert_no_selector ".viewer-pill", visible: :all
  end

  test "a record with one image has no arrows and no thumbnails, and keeps the strip for Use this image" do
    render_media("digital_asset_paths_ssim" => [ "/digital-assets/thumbs/a.jpg" ], "digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg" ],
                 "licence_type_ssim" => [ "Public domain - Copyright expired" ])

    assert_no_selector ".viewer-strip__arrow, .viewer-strip__thumbs"
    assert_selector ".viewer-strip .viewer-strip__use"
    assert_selector ".viewer-pill", visible: :all
  end

  test "the viewer component is the record page's own component with another layout; Object details and Collection and provenance split the fields" do
    presenter = Blacklight::DocumentPresenter.new(doc("object_type_ssim" => [ "tool" ], "accession_number_ssim" => [ "00.1" ], "credit_line_tsim" => [ "Gift" ]), nil, CatalogController.blacklight_config)
    component = NexusCcs::RecordViewerComponent.new(id: "document", component: :div, show: true, document: presenter)

    assert_kind_of NexusCcs::RecordDocumentComponent, component
    details = component.detail_rows.map(&:field)
    provenance = component.provenance_rows.map(&:field)
    assert_includes details, "object_type_ssim"
    assert_includes provenance, "accession_number_ssim"
    assert_empty details & provenance
  end
end
