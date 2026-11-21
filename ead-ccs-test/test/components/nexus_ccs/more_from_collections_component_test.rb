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

  test "You may be interested in: a tab per way the record can match, each panel a lazy frame of its cards (NGA)" do
    render_for(source)

    assert_selector "section#more-from-the-collections h2#record-more-heading", text: "You may be interested in"
    tabs = page.all("[role=tablist][aria-labelledby=record-more-heading] button[role=tab]")
    assert_equal [ "Similar objects", "More by Lees, Derwent" ], tabs.first(2).map(&:text)
    assert_selector "section#more-row-similar turbo-frame#more-similar[loading=lazy][src='/catalog/emu-source/similar?view=tab']"
    assert_includes tabs.map(&:text), "More of this type"
    # the first tab is selected and the only one in the tab order (roving tabindex)
    assert_equal [ "true", "0" ], [ tabs.first["aria-selected"], tabs.first["tabindex"] ]
    assert_equal [ "false", "-1" ], [ tabs.last["aria-selected"], tabs.last["tabindex"] ]
    assert_selector "button#more-tab-creator[aria-controls=more-row-creator]"
    assert_selector "section#more-row-creator[role=tabpanel][aria-labelledby=more-tab-creator] turbo-frame#more-creator[loading=lazy][src='/catalog/emu-source/similar?row=creator'][data-controller=lazy-frame]"
    # without the script every panel shows under its own heading
    assert_equal tabs.size, page.all(".record-more__row h3", visible: :all).size
  end

  test "a record that may not have recommendations beside it has no section" do
    render_for(withheld_record("emu-withheld", creator_ssim: [ "Lees, Derwent" ]))
    assert_no_selector "section", visible: :all

    render_for(sensitive_record("emu-sensitive", creator_ssim: [ "Lees, Derwent" ]))
    assert_no_selector "section", visible: :all
  end
end
