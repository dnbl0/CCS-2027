require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

# The record page's layout components (header, actions, Key facts, no image, About this record, More like this) and the three
# access tiers they must respect: no asset address in the markup for a withheld or not-yet-chosen sensitive record, and no download
# link for a view-only one.
class RecordPageLayoutTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  Presenter = Struct.new(:document)

  def page = Capybara::Node::Simple.new(rendered_content)

  FIELDS = {
    "id" => "emu-1", "title_tsim" => [ "Kangaroo-pouch tone-tool" ], "object_type_ssim" => [ "tone tool" ], "production_date_ssim" => [ "1952" ],
    "creator_ssim" => [ "Grainger, Percy Aldridge" ], "material_ssim" => [ "Paper" ], "classification_ssim" => [ "Music" ],
    "subject_ssim" => [ "Instruments" ], "collection_ssim" => [ "Grainger Museum Collection" ],
    "credit_line_tsim" => [ "Grainger Museum Collection, University of Melbourne." ], "accession_number_ssim" => [ "00.0001" ]
  }.freeze

  IMAGES = { "digital_asset_paths_ssim" => [ "/digital-assets/thumbs/a.jpg", "/digital-assets/thumbs/b.jpg" ],
             "digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg", "/digital-assets/large/b.jpg" ] }.freeze

  # The Save and Add to list controls need a controller; they are tested with the saved-records feature
  setup do
    @saved = Rails.configuration.x.saved_records
    Rails.configuration.x.saved_records = false
  end

  teardown { Rails.configuration.x.saved_records = @saved }

  def doc(extra = {}) = SolrDocument.new(FIELDS.merge(extra))

  def render_actions(extra = {}) = render_inline(NexusCcs::RecordActionsComponent.new(document: doc(extra)))

  def render_media(extra = {}) = render_inline(NexusCcs::DigitalAssetsComponent.new(presenter: Presenter.new(doc(extra))))

  # --- key facts
  test "Key facts are a description list of the facts the record has, and nothing for a record with none" do
    render_inline(NexusCcs::KeyFactsComponent.new(document: doc))

    assert_selector "section.key-facts h2", text: "Key facts"
    assert_equal [ "Date", "Materials", "Classification", "Subject", "Collection", "Credit line" ], page.all("dt").map(&:text)

    render_inline(NexusCcs::KeyFactsComponent.new(document: SolrDocument.new("id" => "x", "material_ssim" => [ "Paper" ])))
    assert_equal [ "Materials" ], page.all("dt").map(&:text)

    render_inline(NexusCcs::KeyFactsComponent.new(document: SolrDocument.new("id" => "x")))
    assert_no_selector ".key-facts"
  end

  # --- actions
  test "an open record with images offers Compare images, Add to compare, Cite and Share, and no access notice" do
    render_actions(IMAGES.merge("licence_type_ssim" => [ "Public domain - Copyright expired" ]))

    assert_selector ".record-actions .compare-actions a[href='/compare?record=emu-1']", text: "Compare images", visible: :all
    assert_selector ".compare-actions form[action='/compare/items'] button", text: "Add to compare", visible: :all
    assert_selector ".record-actions__row .cite__button", visible: :all
    assert_selector ".record-actions__row .share__button", text: /Share and embed/, visible: :all
    assert_no_selector ".access-notice"
  end

  test "Share and Cite are in one row of actions, always shown (nothing folds them away); Compare sits under the row" do
    render_actions(IMAGES)

    assert_no_selector "details", visible: :all
    assert_selector ".record-actions__row .share__button"
    assert_selector ".record-actions__row .cite__button"
    assert_selector ".record-actions__row + .record-actions__compare .compare-actions"
  end

  test "a record with one image offers Add to compare but not Compare images" do
    render_actions("digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg" ], "digital_asset_paths_ssim" => [ "/digital-assets/thumbs/a.jpg" ],
                   "licence_type_ssim" => [ "Public domain - Copyright expired" ])

    assert_no_selector ".compare-actions a", text: "Compare images", visible: :all
    assert_selector ".compare-actions button", text: "Add to compare", visible: :all
  end

  test "a view-only record's actions hold no access notice (Use and access says it) and nothing that downloads" do
    render_actions(IMAGES.merge("licence_type_ssim" => [ "Copyright - Current" ]))

    assert_no_selector ".access-notice"
    assert_selector ".compare-actions button", text: "Add to compare", visible: :all
    assert_no_selector "a[download]"
  end

  test "a request-only, a not-yet-chosen sensitive and an imageless record offer no compare, and no notice here for the first and last" do
    render_actions(IMAGES.merge("licence_type_ssim" => [ "ICIP Rights" ]))
    assert_no_selector ".compare-actions, .access-notice", visible: :all

    render_actions(IMAGES.merge("restrictions_tsi" => [ "Culturally sensitive images" ]))
    assert_no_selector ".compare-actions", visible: :all

    render_actions
    assert_no_selector ".compare-actions, .access-notice", visible: :all
    assert_selector ".cite__button", visible: :all
  end

  # --- media: the three tiers, in markup
  test "an open record has round Zoom and Download at the panel's foot, Media information at its end, and the licence line under it" do
    render_media(IMAGES.merge("licence_type_ssim" => [ "Public domain - Copyright expired" ]))

    assert_selector ".media-viewer__licence", text: "Public domain - Copyright expired. You can view the image online. You can download the image."
    # CCS-67: Download opens the essential information (caption and licence, to copy) before the download
    assert_selector ".media-viewer__controls-start button.round-control[aria-haspopup=dialog][aria-label^='Download image of']"
    assert_selector "dialog .digital-assets__essential dt", text: "Licence", visible: :all
    assert_selector "dialog a.btn[download][href='/digital-assets/large/a.jpg']", text: "Download image", visible: :all
    # CCS-422: Media information opens a drawer from the right
    assert_selector ".media-viewer__controls button.media-viewer__info-button[aria-controls=media-information]", text: "Media information"
    assert_selector "dialog#media-information h2#media-information-heading", text: "Media information", visible: :all
    assert_selector ".media-viewer__controls-start button[aria-label='Zoom into the image']", visible: :all
    assert_no_selector ".digital-assets__stage ~ .digital-assets__stage"
    assert_no_text(/Image \d+ of \d+/) # no counter
  end

  test "a view-only record has no download link in its markup, and the image keeps its own shape (width and height held)" do
    render_media(IMAGES.merge("licence_type_ssim" => [ "Copyright - Current" ]))

    assert_no_selector "a[download], a[href*='/digital-assets/']"
    assert_selector ".media-viewer__licence", text: "Download is not available."
    assert_selector "img.digital-assets__image[src='/digital-assets/large/a.jpg']"
  end

  test "a request-only record's markup holds no asset path, and the notice sits where the media would" do
    render_media(IMAGES.merge("licence_type_ssim" => [ "ICIP Rights" ], "digital_media_ssim" => [ "video|video/mp4|/digital-assets/media/v.mp4|Film" ]))

    assert_selector ".media-viewer__stage .access-notice--request a"
    assert_no_selector "img, video, a[download]"
    assert_not_includes rendered_content, "/digital-assets/"
  end

  test "a sensitive record's markup holds no asset path until the visitor chooses to view it" do
    render_media(IMAGES.merge("restrictions_tsi" => [ "Culturally sensitive images" ]))

    assert_selector ".media-viewer__stage .sensitivity-gate"
    assert_no_selector ".media-viewer__thumbs", visible: :all # thumbnails would show the images
    assert_not_includes rendered_content, "/digital-assets/"
    assert_no_selector "a[download]"
  end

  test "audio, video and PDF keep their viewers" do
    render_media("licence_type_ssim" => [ "Public domain - Copyright expired" ],
                 "digital_media_ssim" => [ "audio|audio/mpeg|/a.mp3|Interview", "video|video/mp4|/v.mp4|Film", "pdf|application/pdf|/d.pdf|Report" ])

    assert_selector "audio"
    assert_selector "video"
    assert_selector "a.digital-assets__pdf[href='/d.pdf']"
    assert_no_selector "a.digital-assets__primary" # no image: no image download
  end

  # --- no image
  test "a record with no image gets one plain sentence, no box or icon, and a request link only where the collection takes questions" do
    render_inline(NexusCcs::NoImageComponent.new(document: doc("collection_ssim" => [ "University Art Collection" ]), url: "http://example.test/catalog/emu-1"))

    assert_selector "p.no-image", text: "No image of this record is available online."
    assert_selector "p.no-image a[target=_blank][href^='https://app.smartsheet.com/']"
    assert_no_selector "svg, img, .record-card"

    render_inline(NexusCcs::NoImageComponent.new(document: doc("collection_ssim" => [ "Medical History Museum" ]), url: "http://example.test/catalog/emu-1"))
    assert_selector "p.no-image a[href^='mailto:mhm.info@unimelb.edu.au?']"

    render_inline(NexusCcs::NoImageComponent.new(document: doc("collection_ssim" => [ "Somewhere else" ]), url: "http://example.test/catalog/emu-1"))
    assert_selector "p.no-image", text: "No image of this record is available online."
    assert_no_selector "p.no-image a"
  end

  # --- about
  test "About this record: a centred heading, the text and content notice, Suggest a correction, the record URL with Copy link, Print and the downloads" do
    render_inline(NexusCcs::RecordAboutComponent.new(document: doc("collection_ssim" => [ "University Art Collection" ]), url: "http://example.test/catalog/emu-1"))

    assert_selector "section#about-this-record h2.record-showcase__section-heading", text: "About this record"
    assert_selector ".record-about__text", text: "not appropriate today"
    assert_selector "a.record-about__button", text: "Suggest a correction"
    assert_selector "[data-controller=clipboard] [data-clipboard-target=source][data-copy='http://example.test/catalog/emu-1']"
    assert_selector ".record-facts__row dt", text: "Record URL"
    assert_selector "button.record-copy", text: "Copy link"
    assert_selector "button[data-action='print#print']", text: "Print this page"
  end

  # --- more like this
  test "More like this is one h2 with an h3 per non-empty sub-section, and no tabs" do
    related = [ SolrDocument.new("id" => "r1", "title_tsim" => [ "Related one" ]) ]
    render_inline(NexusCcs::MoreLikeThisComponent.new(document: doc, related: related, recent: []))

    assert_selector "section#more-like-this h2", text: "More like this", count: 1
    assert_selector "h3", text: "Related objects"
    assert_no_selector "h3", text: "Recently viewed"
    assert_no_selector "[role=tablist], [role=tab]"
    assert_selector ".object-card--text", count: 1
  end

  test "More like this is not drawn when there is nothing to put in it" do
    render_inline(NexusCcs::MoreLikeThisComponent.new(document: doc("restrictions_tsi" => [ "Culturally sensitive images" ]), related: [], recent: []))

    assert_no_selector "#more-like-this"
  end
end
