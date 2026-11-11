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

  # --- header
  test "the header is a kicker (type and collection, plain text), the one h1, the creator as a link with the date, and the Collection ID" do
    render_inline(NexusCcs::RecordHeaderComponent.new(document: doc))

    assert_selector "header.record-header p.record-header__kicker", text: "Tone tool · Grainger Museum Collection"
    assert_selector "h1", count: 1, text: "Kangaroo-pouch tone-tool"
    assert_selector ".record-header__byline", text: "Grainger, Percy Aldridge · 1952"
    assert_selector "[data-testid=record-identifier] button[aria-label='Copy collection ID']"
    assert_no_selector ".record-banner, .record-tag"
  end

  test "an unknown creator is left out of the byline, and a record with no creator or date has no byline" do
    render_inline(NexusCcs::RecordHeaderComponent.new(document: doc("creator_ssim" => [ "Unknown" ], "production_date_ssim" => [])))

    assert_no_selector ".record-header__byline"
  end

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

    assert_selector ".record-actions .compare-actions a[href='/compare?record=emu-1']", text: "Compare images"
    assert_selector ".compare-actions form[action='/compare/items'] button", text: "Add to compare"
    assert_selector ".record-summary__cite .cite__button"
    assert_selector ".record-summary__share .share__button", text: /Share and embed/
    assert_no_selector ".access-notice"
  end

  test "a record with one image offers Add to compare but not Compare images" do
    render_actions("digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg" ], "digital_asset_paths_ssim" => [ "/digital-assets/thumbs/a.jpg" ],
                   "licence_type_ssim" => [ "Public domain - Copyright expired" ])

    assert_no_selector ".compare-actions a", text: "Compare images"
    assert_selector ".compare-actions button", text: "Add to compare"
  end

  test "a view-only record's access notice is in the actions, with the request link and nothing that downloads" do
    render_actions(IMAGES.merge("licence_type_ssim" => [ "Copyright - Current" ]))

    assert_selector ".record-actions .access-notice--view-only a[href='/access_requests/new?document_id=emu-1']", text: "Request access to download this item"
    assert_selector ".compare-actions button", text: "Add to compare"
    assert_no_selector "a[download]"
  end

  test "a request-only, a not-yet-chosen sensitive and an imageless record offer no compare, and no notice here for the first and last" do
    render_actions(IMAGES.merge("licence_type_ssim" => [ "ICIP Rights" ]))
    assert_no_selector ".compare-actions, .access-notice"

    render_actions(IMAGES.merge("restrictions_tsi" => [ "Culturally sensitive images" ]))
    assert_no_selector ".compare-actions"

    render_actions
    assert_no_selector ".compare-actions, .access-notice"
    assert_selector ".cite__button"
  end

  # --- media: the three tiers, in markup
  test "an open record has a Download image link, the access chip, the licence, and the labelled media buttons in one toolbar" do
    render_media(IMAGES.merge("licence_type_ssim" => [ "Public domain - Copyright expired" ]))

    assert_selector ".digital-assets__toolbar .digital-assets__access--open", text: "Open: view and download"
    assert_selector ".digital-assets__toolbar a.digital-assets__primary[download][href='/digital-assets/large/a.jpg']", text: "Download image"
    assert_selector ".digital-assets__toolbar button", text: "Full screen", visible: :all
    assert_no_selector ".digital-assets__stage ~ .digital-assets__stage"
  end

  test "a view-only record has no download link in its markup, and the image keeps its own shape (width and height held)" do
    render_media(IMAGES.merge("licence_type_ssim" => [ "Copyright - Current" ]))

    assert_no_selector "a[download], a.digital-assets__primary, a[href*='/digital-assets/']"
    assert_selector ".digital-assets__access--view-only", text: "View only"
    assert_selector "img.digital-assets__image[src='/digital-assets/large/a.jpg']"
  end

  test "a request-only record's markup holds no asset path, and the notice sits where the media would" do
    render_media(IMAGES.merge("licence_type_ssim" => [ "ICIP Rights" ], "digital_media_ssim" => [ "video|video/mp4|/digital-assets/media/v.mp4|Film" ]))

    assert_selector ".digital-assets__media-area .access-notice--request a"
    assert_no_selector "img, video, a[download]"
    assert_not_includes rendered_content, "/digital-assets/"
  end

  test "a sensitive record's markup holds no asset path until the visitor chooses to view it" do
    render_media(IMAGES.merge("restrictions_tsi" => [ "Culturally sensitive images" ]))

    assert_selector ".digital-assets__media-area .sensitivity-gate"
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
  test "About this record has the persistent link with Copy link, who to contact with the ID, and a correction link" do
    render_inline(NexusCcs::RecordAboutComponent.new(document: doc("collection_ssim" => [ "University Art Collection" ]), url: "http://example.test/catalog/emu-1"))

    assert_selector "details#about-this-record h2", text: "About this record"
    # closed in the markup (a phone opens it), so look at all of it
    assert_selector "[data-controller=clipboard] input[readonly][value='http://example.test/catalog/emu-1']", visible: :all
    assert_selector "button[data-action='clipboard#copy']", text: "Copy link", visible: :all
    assert_selector "h3", text: "Contact the collection team", visible: :all
    assert_selector "strong", text: "emu-umc-1", visible: :all
    assert_selector ".record-about__correction a", text: "Suggest a correction to this record", visible: :all
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
