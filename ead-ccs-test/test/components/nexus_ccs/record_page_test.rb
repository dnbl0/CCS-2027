require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

class RecordPageTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  Presenter = Struct.new(:document)

  def page = Capybara::Node::Simple.new(rendered_content)

  def render_embed(fields)
    render_inline(NexusCcs::RecordEmbedComponent.new(presenter: Presenter.new(SolrDocument.new(fields))))
  end

  test "the summary has the type and collection, the creator and date, and the licence" do
    render_embed(
      "object_type_ssim" => [ "painting", "artwork" ], "collection_ssim" => [ "Medical History Museum" ],
      "creator_display_ssim" => [ "Judy Mengil (b.1954, d.2017), artist" ], "production_date_ssim" => [ "2016" ],
      "licence_type_ssim" => [ "Copyright - Current" ]
    )

    assert_selector ".record-summary__eyebrow", text: "painting; artwork • Medical History Museum"
    assert_selector ".record-summary__byline", text: "Judy Mengil (b.1954, d.2017), artist · 2016"
    assert_selector ".record-summary__licence", text: "Copyright - Current"
    assert_selector ".record-summary__licence .visually-hidden", text: "Licence:"
  end

  test "parts of the summary with no data are left out, and a record with none has no summary" do
    render_embed("collection_ssim" => [ "Grainger Museum Collection" ])
    assert_selector ".record-summary__eyebrow", text: "Grainger Museum Collection"
    assert_no_selector ".record-summary__byline"
    assert_no_selector ".record-summary__licence"

    render_embed("title_tsim" => [ "Untitled" ])
    assert_no_selector ".record-summary"
  end

  test "the embed shows the digital assets above the summary" do
    render_embed(
      "title_tsim" => [ "Microscope" ], "collection_ssim" => [ "Medical History Museum" ],
      "digital_asset_paths_ssim" => [ "/digital-assets/thumbs/a.jpg" ], "digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg" ]
    )

    assert_selector ".digital-assets + .record-summary"
  end

  test "the title band is hidden from assistive technology so the visible title in the summary is the one h1" do
    render_inline(NexusCcs::RecordBannerComponent.new(title: "Dimalan Leaves"))

    assert_selector "section.record-banner[aria-hidden=true] p.record-banner__title", text: "Dimalan Leaves"
    assert_no_selector "h1"
  end

  test "a record page has the title band and no search banner" do
    with_controller_class(CatalogController) do
      with_request_url("/catalog/vernon-MHM2017.28") do
        vc_test_controller.action_name = "show"
        render_inline(NexusCcs::HeaderComponent.new(blacklight_config: CatalogController.blacklight_config))
      end
    end

    assert_selector ".record-banner"
    assert_no_selector ".search-banner"
  end

  test "the persistent link has the link, a copy button and a status line for screen readers" do
    render_inline(NexusCcs::PersistentLinkComponent.new(url: "http://example.test/catalog/x"))

    assert_selector "section.persistent-link[data-controller=clipboard] input[readonly][value='http://example.test/catalog/x']"
    assert_selector "button[data-action='clipboard#copy']", text: "Copy link"
    assert_selector "[role=status][data-clipboard-target=status]", visible: :all
  end

  test "the persistent link tells the visitor to quote the record's accession number" do
    document = SolrDocument.new(id: "emu-1", accession_number_ssim: [ "1996.3014.000.000" ])
    render_inline(NexusCcs::PersistentLinkComponent.new(url: "http://example.test/catalog/emu-1", document: document))

    assert_selector ".persistent-link__note", text: "Quote the accession number 1996.3014.000.000 when contacting the collection team."
  end

  test "the persistent link note falls back to the link when the record has no accession number" do
    render_inline(NexusCcs::PersistentLinkComponent.new(url: "http://example.test/catalog/x", document: SolrDocument.new(id: "x")))

    assert_selector ".persistent-link__note", text: "Quote this link when contacting the collection team."
  end

  test "the persistent link and the contact card are show partials" do
    assert_equal [ :persistent_link, :contact_collection ], CatalogController.blacklight_config.view_config(:show).partials
  end
end
