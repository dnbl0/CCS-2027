require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

# The "Contact the collection team" card on a record page (CCS-47)
class ContactCollectionComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  def page = Capybara::Node::Simple.new(rendered_content)

  def render_card(fields = {})
    document = SolrDocument.new({ "id" => "vernon-MHM00394", "title_tsim" => [ "Microscope" ],
                                  "collection_ssim" => [ "Medical History Museum" ], "licence_type_ssim" => [ "Public domain - Copyright expired" ] }.merge(fields))
    render_inline(NexusCcs::ContactCollectionComponent.new(document: document, url: "http://example.test/catalog/#{document.id}"))
  end

  def mailto_params
    href = page.find("a[href^='mailto:']")[:href]
    Rack::Utils.parse_query(href.split("?", 2).last)
  end

  test "an email collection gets one mailto link to its address, with the record's ID as the subject" do
    render_card

    assert_selector "[aria-labelledby=contact-collection-heading] h3#contact-collection-heading", text: "Contact the collection team"
    assert_selector "a[href^='mailto:mhm.info@unimelb.edu.au?']", text: "mhm.info@unimelb.edu.au", count: 1
    assert_equal "vernon-MHM00394", mailto_params["subject"]
  end

  test "the email starts with the record's title, ID and link so the team knows where the request came from" do
    render_card("accession_number_ssim" => [ "1996.3014" ])

    body = mailto_params["body"]
    assert_includes body, "Microscope"
    assert_includes body, "http://example.test/catalog/vernon-MHM00394"
    assert_includes body, "1996.3014"
  end

  test "an EMu record's subject is its UoM ID" do
    render_card("id" => "emu-9044")

    assert_equal "emu-umc-9044", mailto_params["subject"]
  end

  test "a Smartsheet collection links to the form, opening in a new tab and saying so" do
    render_card("collection_ssim" => [ "Grainger Museum Collection" ])

    assert_no_selector "a[href^='mailto:']"
    assert_selector "a[href^='https://app.smartsheet.com/b/form/'][target=_blank][rel~=noopener]", text: /Access Request Form.*opens in a new tab/
  end

  test "names the collection, so the visitor knows who they are writing to" do
    render_card

    assert_selector ".contact-collection__team", text: "Medical History Museum"
  end

  test "a collection with no contact points to the Contact us section of Help" do
    render_card("collection_ssim" => [ "Somewhere Else" ])

    assert_no_selector "a[href^='mailto:']"
    assert_selector "a[href='/help#contact-us']"
  end

  test "it keeps Contact us apart from Request access: the access link appears only when the assets are gated" do
    render_card
    assert_no_selector "a[href^='/access_requests/new']"

    render_card("licence_type_ssim" => [ "Copyright - Current" ])
    assert_selector "a[href='/access_requests/new?document_id=vernon-MHM00394']", text: "Request access"
  end

  test "the help tip beside the heading is a button that controls real text" do
    render_card

    assert_selector "button[aria-expanded=false][aria-controls]", text: /About contacting the team/
    controls = page.find("button[aria-expanded]")[:"aria-controls"]
    assert_selector "##{controls}[hidden]", visible: :all, text: /accession number/
  end
end
