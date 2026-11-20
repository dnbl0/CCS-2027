require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"
require_relative "../../support/discovery_records"

# "More from the collections" (approved split layout): one labelled row per way the record matches, each a lazy frame
class MoreFromCollectionsComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions
  include DiscoveryRecords

  def page = Capybara::Node::Simple.new(rendered_content)

  def render_for(fields) = render_inline(NexusCcs::MoreFromCollectionsComponent.new(document: SolrDocument.new(fields)))

  def source(**extra) = open_record("emu-source", creator_ssim: [ "Lees, Derwent" ], object_type_ssim: [ "drawing" ], **extra)

  test "a labelled row per way the record can match, all in view, each a lazy frame of its cards; no tabs" do
    render_for(source)

    assert_selector "section#more-from-the-collections h2", text: "More from the collections"
    assert_no_selector "[role=tablist], [role=tab], [role=tabpanel]", visible: :all
    headings = page.all(".record-more__row h3", visible: :all).map { |heading| heading.text(:all) }
    assert_equal "More by Lees, Derwent", headings.first
    assert_includes headings, "More of this type"
    # two rows at first; the others behind "More ways to explore", their frames loading only once it is opened
    assert_equal 2, page.all(".record-more__inner > .record-more__row").size
    assert_selector "details.record-more__others .record-more__row", visible: :all
    assert_selector "details.record-more__others summary", text: "More ways to explore"
    assert_selector "section#more-row-creator[aria-labelledby=more-row-creator-heading] turbo-frame#more-creator[loading=lazy][src='/catalog/emu-source/similar?row=creator'][data-controller=lazy-frame]"
  end

  test "a record that may not have recommendations beside it has no section" do
    render_for(withheld_record("emu-withheld", creator_ssim: [ "Lees, Derwent" ]))
    assert_no_selector "section", visible: :all

    render_for(sensitive_record("emu-sensitive", creator_ssim: [ "Lees, Derwent" ]))
    assert_no_selector "section", visible: :all
  end
end
