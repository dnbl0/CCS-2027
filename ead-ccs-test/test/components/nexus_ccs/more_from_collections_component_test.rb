require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"
require_relative "../../support/discovery_records"

# "More from the collections" (approved split layout): one ARIA tab per way the record matches, each panel a lazy frame
class MoreFromCollectionsComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions
  include DiscoveryRecords

  def page = Capybara::Node::Simple.new(rendered_content)

  def render_for(fields) = render_inline(NexusCcs::MoreFromCollectionsComponent.new(document: SolrDocument.new(fields)))

  def source(**extra) = open_record("emu-source", creator_ssim: [ "Lees, Derwent" ], object_type_ssim: [ "drawing" ], **extra)

  test "a tab per row the record can match on, the maker's named, the first selected; each panel a lazy frame of the tab's cards" do
    render_for(source)

    assert_selector "section#more-from-the-collections h2", text: "More from the collections"
    assert_selector "[role=tablist][aria-label='Ways to explore'][hidden]", visible: :all
    tabs = page.all("[role=tab]", visible: :all)
    assert_equal "By Lees, Derwent", tabs.first.text(:all).strip
    assert_equal %w[true], tabs.map { |tab| tab["aria-selected"] }.uniq.first(1)
    assert_equal [ "0" ], [ tabs.first["tabindex"] ]
    assert(tabs.drop(1).all? { |tab| tab["aria-selected"] == "false" && tab["tabindex"] == "-1" })
    assert_selector "#record-panel-creator[aria-labelledby=record-tab-creator] turbo-frame#more-creator[loading=lazy][src='/catalog/emu-source/similar?row=creator'][data-controller=lazy-frame]", visible: :all
    # without JavaScript every panel shows under its own heading
    assert_selector ".record-tabs__panel h3", text: "By Lees, Derwent", visible: :all
  end

  test "a record that may not have recommendations beside it has no section" do
    render_for(withheld_record("emu-withheld", creator_ssim: [ "Lees, Derwent" ]))
    assert_no_selector "section", visible: :all

    render_for(sensitive_record("emu-sensitive", creator_ssim: [ "Lees, Derwent" ]))
    assert_no_selector "section", visible: :all
  end
end
