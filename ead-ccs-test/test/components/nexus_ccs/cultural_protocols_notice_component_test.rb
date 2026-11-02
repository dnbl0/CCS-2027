require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

class CulturalProtocolsNoticeComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  def page = Capybara::Node::Simple.new(rendered_content)

  def render_for(fields)
    render_inline(NexusCcs::CulturalProtocolsNoticeComponent.new(document: SolrDocument.new({ "id" => "emu-1" }.merge(fields))))
  end

  test "an ICIP Rights record says cultural protocols apply, and points to Help and the collection team" do
    render_for("licence_type_ssim" => [ "Copyright - Current", "ICIP Rights" ])

    assert_selector "aside[aria-labelledby=record-cultural-protocols-title] h2", text: "Cultural protocols apply to this record"
    assert_text "Indigenous Cultural and Intellectual Property"
    assert_selector "a[href='/help#indigenous']"
    assert_selector "a[href='/help#contact-us']"
  end

  test "a Community Restricted record and a record noted as culturally sensitive each get a notice with their own reason" do
    render_for("access_condition_ssi" => "Community Restricted")
    assert_text "limited to a community"

    render_for("restrictions_tsi" => [ "Not for publishing Culturally sensitive images" ])
    assert_text "needs cultural care"
  end

  test "an ordinary or merely sensitive-in-other-ways record has no notice" do
    render_for("licence_type_ssim" => [ "Copyright - Current" ], "restrictions_tsi" => [ "Sensitive medical specimen" ])

    assert_equal "", rendered_content.strip
  end

  test "the notice changes nothing about the access tier" do
    document = SolrDocument.new("id" => "emu-1", "licence_type_ssim" => [ "ICIP Rights" ])

    assert_equal :request, AccessPolicy.tier(document)
    assert_equal :view_only, AccessPolicy.tier(SolrDocument.new("licence_type_ssim" => [ "Copyright - Current" ]))
  end
end
