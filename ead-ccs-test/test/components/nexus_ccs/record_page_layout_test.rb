require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

# The record page's layout components (header, actions rail, related rail, no image, About this record, More like this) and the three
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
    assert_selector ".record-header__place", text: "Paper" # no place: the material
    assert_no_selector "[data-testid=record-identifier]" # the Collection ID is in the actions rail
    assert_no_selector ".record-banner, .record-tag"
  end

  test "an unknown creator is left out of the byline, and a record with no creator or date has no byline" do
    render_inline(NexusCcs::RecordHeaderComponent.new(document: doc("creator_ssim" => [ "Unknown" ], "production_date_ssim" => [])))

    assert_no_selector ".record-header__byline"
  end

  # --- the details list and the rail
  test "the description is read first, and Object details lists the rest with chips for the terms that link" do
    component = NexusCcs::RecordDocumentComponent.new(id: "document", component: :div, show: true,
                                                      document: Blacklight::DocumentPresenter.new(doc("description_tsim" => [ "A long account." ]), nil, CatalogController.blacklight_config))

    assert_equal "A long account.", component.description_row.values.first
    assert_not_includes component.rows.map(&:field), "description_tsim"
    assert_includes component.rows.map(&:field), "material_ssim"
    assert component.chips?(component.rows.find { |row| row.field == "material_ssim" })
    assert_not component.chips?(component.rows.find { |row| row.field == "accession_number_ssim" })
    assert_equal({ f: { "material_ssim" => [ "Paper" ] } }, component.filter_query("material_ssim", "Paper"))
  end

  test "the rail ends with the Collection ID and its Copy button" do
    render_actions

    assert_selector "[data-testid=record-identifier] button[aria-label='Copy collection ID']", visible: :all
    assert_selector "[data-testid=record-identifier]", text: /Grainger Museum Collection, accession number 00\.0001/, visible: :all
  end

  test "the sub-navigation has the title and anchors to the sections, and leaves out a section the record cannot have" do
    render_inline(NexusCcs::RecordSubnavComponent.new(document: doc))

    assert_selector "nav.record-subnav[aria-label='On this page'] .record-subnav__title", text: "Kangaroo-pouch tone-tool"
    assert_equal [ "#record-overview", "#record-details", "#record-copyright", "#about-this-record" ], page.all(".record-subnav__links a").map { |link| link["href"] }.first(4)

    render_inline(NexusCcs::RecordSubnavComponent.new(document: doc("restrictions_tsi" => [ "Culturally sensitive images" ]), details: false))
    assert_no_selector "a[href='#record-details'], a[href='#more-like-this']"
  end

  # --- actions
  test "an open record has the access card: a large line, one full-width Download image button, and the quiet text actions" do
    render_actions(IMAGES.merge("licence_type_ssim" => [ "Public domain - Copyright expired" ]))

    assert_selector ".record-actions .compare-actions a[href='/compare?record=emu-1']", text: "Compare images", visible: :all
    assert_selector ".compare-actions form[action='/compare/items'] button", text: "Add to compare", visible: :all
    assert_selector ".record-summary__cite .cite__button", visible: :all
    assert_selector ".access-card__headline", text: "Download this image"
    assert_selector "a.access-card__primary[download][href='/digital-assets/large/a.jpg']", text: "Download image"
    assert_selector ".record-summary__share .share__button", text: /Share and embed/, visible: :all
    assert_no_selector ".access-notice"
  end

  test "Compare, Cite and Share are tiles in one grid with the other actions, with no disclosure" do
    render_actions(IMAGES)

    assert_selector ".record-actions__row[style*='--record-tiles']"
    assert_selector ".record-actions__row .compare-actions__button svg", visible: :all
    assert_selector ".record-actions__row .record-summary__cite .cite__button"
    assert_selector ".record-actions__row .record-summary__share .share__button"
    assert_no_selector "details.record-actions__more", visible: :all
  end

  test "a record with one image offers Add to compare but not Compare images" do
    render_actions("digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg" ], "digital_asset_paths_ssim" => [ "/digital-assets/thumbs/a.jpg" ],
                   "licence_type_ssim" => [ "Public domain - Copyright expired" ])

    assert_no_selector ".compare-actions a", text: "Compare images", visible: :all
    assert_selector ".compare-actions button", text: "Add to compare", visible: :all
  end

  test "a record with no media has no large line and no primary button, only the quiet actions" do
    render_actions

    assert_no_selector ".access-card__headline, .access-card__primary"
    assert_selector ".record-actions__row .record-summary__share .share__button", text: /Share and embed/
  end

  test "a view-only record's card says so in plain text with a link to ask, and has no button and nothing that downloads" do
    render_actions(IMAGES.merge("licence_type_ssim" => [ "Copyright - Current" ]))

    assert_selector ".access-card__headline", text: "View only"
    assert_selector ".access-card__reason a[href='/access_requests/new?document_id=emu-1']", text: "Request access to download this item"
    assert_no_selector ".access-card__primary, a[download], .access-notice"
  end

  test "a request-only record's card has one Request access button, and no asset address" do
    render_actions(IMAGES.merge("licence_type_ssim" => [ "ICIP Rights" ]))

    assert_selector ".access-card__headline", text: "Request access"
    assert_selector "a.access-card__primary[href='/access_requests/new?document_id=emu-1']"
    assert_not_includes rendered_content, "/digital-assets/"
  end

  test "a request-only, a not-yet-chosen sensitive and an imageless record offer no compare, and no notice here for the first and last" do
    render_actions(IMAGES.merge("licence_type_ssim" => [ "ICIP Rights" ]))
    assert_no_selector ".compare-actions", visible: :all

    render_actions(IMAGES.merge("restrictions_tsi" => [ "Culturally sensitive images" ]))
    assert_no_selector ".compare-actions", visible: :all

    render_actions
    assert_no_selector ".compare-actions", visible: :all
    assert_selector ".cite__button", visible: :all
  end

  # --- media: the three tiers, in markup
  test "the viewer has round controls on the stage, the strip of images, and three short lines under it: access, licence, what there is" do
    render_media(IMAGES.merge("licence_type_ssim" => [ "Public domain - Copyright expired" ]))

    assert_selector ".digital-assets__stage .digital-assets__overlay button", text: "Media information"
    assert_selector ".digital-assets__stage .digital-assets__overlay button", text: "Full screen", visible: :all
    assert_selector ".digital-assets__stage + .digital-assets__others li", count: 2
    assert_selector ".digital-assets__facts .digital-assets__access--open", text: "Open: view and download"
    assert_selector ".digital-assets__facts .digital-assets__licence", text: "Public domain - Copyright expired"
    assert_selector ".digital-assets__facts .digital-assets__files", text: "2 images"
    assert_no_selector "a[download]" # Download image is the access card's one button
  end

  test "a view-only record has no download link in its markup, and the image keeps its own shape (width and height held)" do
    render_media(IMAGES.merge("licence_type_ssim" => [ "Copyright - Current" ]))

    assert_no_selector "a[download], a.digital-assets__primary, a[href*='/digital-assets/']"
    assert_selector ".digital-assets__facts .digital-assets__access--view-only", text: "View only"
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

    assert_selector "div.no-image .no-image__text", text: "No image of this record is available online."
    assert_selector ".no-image a[target=_blank][href^='https://app.smartsheet.com/']"
    assert_selector ".no-image__monogram[aria-hidden=true]", text: "UA"
    assert_no_selector "svg, img, .record-card"

    render_inline(NexusCcs::NoImageComponent.new(document: doc("collection_ssim" => [ "Medical History Museum" ]), url: "http://example.test/catalog/emu-1"))
    assert_selector ".no-image a[href^='mailto:mhm.info@unimelb.edu.au?']"

    render_inline(NexusCcs::NoImageComponent.new(document: doc("collection_ssim" => [ "Somewhere else" ]), url: "http://example.test/catalog/emu-1"))
    assert_selector ".no-image", text: "No image of this record is available online."
    assert_no_selector ".no-image a"
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
    related = 3.times.map { |n| SolrDocument.new("id" => "r#{n}", "title_tsim" => [ "Related #{n}" ]) }
    render_inline(NexusCcs::MoreLikeThisComponent.new(document: doc, related: related, recent: []))

    assert_selector "section#more-like-this h2", text: "More like this", count: 1
    assert_selector "h3", text: "Related objects"
    assert_selector ".object-card", count: 3
    assert_no_selector "h3", text: "Recently viewed"
    assert_no_selector "[role=tablist], [role=tab]"
  end

  test "More like this is not drawn when there is nothing to put in it" do
    render_inline(NexusCcs::MoreLikeThisComponent.new(document: doc("restrictions_tsi" => [ "Culturally sensitive images" ]), related: [], recent: []))

    assert_no_selector "#more-like-this"
  end
end
