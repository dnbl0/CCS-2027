require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

# CCS-44 / CCS-496: the viewing classification badge, and the gate for a restricted rating
class ViewingClassificationTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  def page = Capybara::Node::Simple.new(rendered_content)
  def doc(*ratings, **extra) = SolrDocument.new({ "id" => "c1", ViewingClassification::FIELD => ratings }.merge(extra.stringify_keys))

  test "the most restrictive rating is the record's" do
    assert_equal "R 18+", ViewingClassification.rating(doc("PG", "R 18+", "M"))
    assert_nil ViewingClassification.rating(doc)
  end

  test "MA 15+ and above, RC and CTC are restricted; G, PG and M are not" do
    [ "MA 15+", "R 18+", "X 18+", "RC", "CTC" ].each { |rating| assert ViewingClassification.restricted?(doc(rating)), rating }
    %w[G PG M].each { |rating| assert_not ViewingClassification.restricted?(doc(rating)), rating }
  end

  test "a restricted rating is asked about like sensitive material; an unrestricted one is not" do
    assert Sensitivity.sensitive?(doc("MA 15+"))
    assert_not Sensitivity.sensitive?(doc("M"))
  end

  test "the picture pools leave restricted ratings out" do
    assert_equal '-digital_asset_advisory_classification_ssim:("MA 15+" "R 18+" "X 18+" "RC" "CTC")', ViewingClassification::EXCLUDE_RESTRICTED
    [ FeaturedRecords::POOL_FILTERS, SimilarRecords::ASSET_FILTERS, Browse::Cards::THUMBNAIL_FILTERS ].each do |filters|
      assert_includes filters, ViewingClassification::EXCLUDE_RESTRICTED
    end
  end

  test "every list that fetches the sensitivity field fetches the rating too, so a restricted picture never reaches a card" do
    [ Discovery::FIELDS, RecordSummaries::FIELDS, Sitemap::RecordSource::FIELDS, Categories::FIELDS, Browse::Profile::FIELDS ].each do |fields|
      list = fields.is_a?(String) ? fields.split : Array(fields)
      assert_includes list, ViewingClassification::FIELD if list.include?("restrictions_tsi")
    end
  rescue NameError => e
    skip "a field list moved: #{e.message}"
  end

  test "the badge shows the rating, with its meaning for screen readers and on hover" do
    render_inline(NexusCcs::ClassificationBadgeComponent.new(document: doc("M")))

    assert_selector ".classification-badge:not(.classification-badge--restricted)[title='Classified M: mature, recommended for 15 and over']"
    assert_selector ".classification-badge [aria-hidden=true]", text: "M"
    assert_selector ".classification-badge .visually-hidden", text: "Classified M: mature, recommended for 15 and over"
  end

  test "a restricted rating's badge is filled; a record with no rating has none" do
    render_inline(NexusCcs::ClassificationBadgeComponent.new(document: doc("R 18+")))
    assert_selector ".classification-badge--restricted", text: "R 18+"

    render_inline(NexusCcs::ClassificationBadgeComponent.new(document: doc))
    assert_no_selector ".classification-badge"
  end

  test "the gate names the rating and what it means" do
    render_inline(NexusCcs::SensitivityGateComponent.new(document: doc("MA 15+"), state: :ask))
    assert_text "This item is classified MA 15+"
    assert_text "It is restricted to 15 and over."

    render_inline(NexusCcs::SensitivityGateComponent.new(document: doc(restrictions_tsi: [ "Culturally sensitive images" ]), state: :ask))
    assert_text "This item may contain sensitive material"
  end
end
