require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

# The viewer layout of a record page (?layout=viewer): the viewer with its grouped pill, the access rules in markup (no asset path for a
# withheld or not-yet-chosen sensitive record, no download link for a view-only one), and the record's buttons and accordions.
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

  test "the viewer has one grouped pill of four icon buttons, each named, a counter, a strip with the current image outlined, and the keys line" do
    render_media(IMAGES.merge("licence_type_ssim" => [ "Copyright - Current" ]))

    assert_selector ".viewer-pill[role=group] button.viewer-pill__button", count: 4, visible: :all
    %w[Zoom\ in Zoom\ out Reset\ view Full\ screen].each { |name| assert_selector ".viewer-pill button[aria-label='#{name}']", visible: :all }
    assert_selector ".viewer-pill button[disabled][aria-label='Zoom out']", visible: :all # nothing to zoom out of until the viewer is on
    assert_selector ".viewer-media__counter", text: "1 of 3"
    assert_selector ".viewer-media__strip li", count: 3
    assert_selector ".viewer-media__thumb.is-current[aria-current=true]", count: 1
    assert_selector ".viewer-media__keys", text: "+ and - to zoom, 0 to reset"
    assert_no_selector "[data-deep-zoom-target=toggle]", visible: :all # the pill replaces the toggle
    assert_selector "canvas, #viewer-navigator[hidden]", visible: :all
    assert_selector "#viewer-description.visually-hidden", text: "A tool for tone."
  end

  test "a view-only record's viewer has no download link in its markup" do
    render_media(IMAGES.merge("licence_type_ssim" => [ "Copyright - Current" ]))

    assert_no_selector "a[download], a[href*='/digital-assets/']"
    assert_selector "button.viewer-media__thumb[data-media-viewer-large]", count: 3
  end

  test "an open record has the one Download image link, under the viewer" do
    render_media(IMAGES.merge("licence_type_ssim" => [ "Public domain - Copyright expired" ]))

    assert_selector ".viewer-media__caption a[download][href='/digital-assets/large/a.jpg']", text: "Download image"
  end

  test "a request-only or not-yet-chosen sensitive record has no asset address in the viewer, and the notice is inside the picture area" do
    render_media(IMAGES.merge("licence_type_ssim" => [ "ICIP Rights" ]))
    assert_selector ".viewer-media__picture .access-notice--request"
    assert_not_includes rendered_content, "/digital-assets/"

    render_media(IMAGES.merge("restrictions_tsi" => [ "Culturally sensitive images" ]))
    assert_selector ".viewer-media__picture .sensitivity-gate"
    assert_not_includes rendered_content, "/digital-assets/"
  end

  test "a record with one image has no counter and no strip" do
    render_media("digital_asset_paths_ssim" => [ "/digital-assets/thumbs/a.jpg" ], "digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg" ],
                 "licence_type_ssim" => [ "Public domain - Copyright expired" ])

    assert_no_selector ".viewer-media__counter, .viewer-media__strip"
    assert_selector ".viewer-pill", visible: :all
  end

  test "the viewer component is the record page's own component with another layout, and its primary button follows the access tier" do
    component = ->(fields) { NexusCcs::RecordViewerComponent.new(id: "document", component: :div, show: true, related: [],
                                                                  document: Blacklight::DocumentPresenter.new(doc(fields), nil, CatalogController.blacklight_config)) }

    assert_kind_of NexusCcs::RecordDocumentComponent, component.({})
    assert_not component.({ "digital_asset_large_paths_ssim" => [ "/x.jpg" ] }).request_access?
    request_only = component.({ "licence_type_ssim" => [ "ICIP Rights" ], "digital_asset_large_paths_ssim" => [ "/x.jpg" ] })
    assert request_only.request_access?
    assert_equal "/access_requests/new?document_id=emu-1", request_only.primary_href
    assert_equal "https://app.smartsheet.com/b/form/209fed78a83f400e80d0836d6fb517c4", component.({}).primary_href
  end

  test "Object details and Collection and provenance split the fields; neither repeats the other" do
    presenter = Blacklight::DocumentPresenter.new(doc("object_type_ssim" => [ "tool" ], "accession_number_ssim" => [ "00.1" ], "credit_line_tsim" => [ "Gift" ]), nil, CatalogController.blacklight_config)
    component = NexusCcs::RecordViewerComponent.new(id: "document", component: :div, show: true, related: [], document: presenter)
    details = component.detail_rows.map(&:field)
    provenance = component.provenance_rows.map(&:field)

    assert_includes details, "object_type_ssim"
    assert_includes provenance, "accession_number_ssim"
    assert_empty details & provenance
  end
end
