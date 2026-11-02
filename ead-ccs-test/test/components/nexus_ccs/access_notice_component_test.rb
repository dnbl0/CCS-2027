require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

class AccessNoticeComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  def page = Capybara::Node::Simple.new(rendered_content)

  def render_for(licence)
    render_inline(NexusCcs::AccessNoticeComponent.new(document: SolrDocument.new("id" => "emu-1", "licence_type_ssim" => [ licence ])))
  end

  test "an open record has no notice" do
    render_for("Public domain - Copyright expired")

    assert_equal "", rendered_content.strip
  end

  test "a view-only record says it can be viewed, not downloaded, and links to the request form" do
    render_for("Copyright - Current")

    assert_selector ".access-notice--view-only", text: "You can view this item, but not download it"
    assert_text "ask the collection team for access"
    assert_text "Your request needs approval"
    assert_selector "a[href='/access_requests/new?document_id=emu-1']", text: "Request access to download this item"
  end

  test "a request record says the asset is not shown, and links to the request form" do
    render_for("ICIP Rights")

    assert_selector ".access-notice--request", text: "This item is available on request"
    assert_text "not shown here"
    assert_selector "a[href='/access_requests/new?document_id=emu-1']", text: "Request access to this item"
  end

  test "it is static text: no role, no live region, no heading to disturb the page's outline" do
    render_for("Copyright")

    assert_no_selector "[role], [aria-live], h1, h2, h3, h4, h5, h6"
  end
end
