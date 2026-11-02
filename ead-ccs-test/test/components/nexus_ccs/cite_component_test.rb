require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

class CiteComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  def page = Capybara::Node::Simple.new(rendered_content)

  def render_cite(fields = {})
    document = SolrDocument.new({ "id" => "emu-1", "title_tsim" => [ "Ukulele" ], "creator_ssim" => [ "Grainger, Percy" ],
                                  "production_date_ssim" => [ "1922" ] }.merge(fields))
    render_inline(NexusCcs::CiteComponent.new(document: document, accessed: Date.new(2026, 11, 2)))
  end

  test "a button opens a dialog named by its heading" do
    render_cite
    assert_selector "button[aria-haspopup=dialog]", text: "Cite this record"
    assert_selector "dialog[aria-labelledby=cite-emu-1-title]", visible: :all
    assert_selector "dialog h2#cite-emu-1-title", text: "Cite this record", visible: :all
  end

  test "every style has a heading, its citation, and a Copy button named for the style that holds the visible word Copy" do
    render_cite
    Citation::STYLES.each do |style|
      label = Citation.label(style)
      assert_selector "dialog h3", text: label, visible: :all
      button = page.find("button[aria-label='Copy #{label} citation']", visible: :all)
      assert_equal "Copy", button.find("span", visible: :all).text(:all)
    end
    assert_selector "dialog .cite__text", count: 4, visible: :all
    assert_selector "dialog .cite__text", text: "Grainger, P. (1922). Ukulele.", visible: :all
  end

  test "the citation links to the persistent link /catalog/:id" do
    render_cite
    assert_includes page.find("dialog .cite__text", match: :first, visible: :all).text(:all), "/catalog/emu-1"
  end

  test "each copy button has its own polite status line, and the copy source is the citation text" do
    render_cite
    assert_selector "dialog [role=status][data-clipboard-target=status]", count: 4, visible: :all
    assert_selector "dialog .cite__item[data-controller=clipboard]", count: 4, visible: :all
    page.all("dialog .cite__text", visible: :all).each { |node| assert_equal node.text(:all), node["data-copy"] }
  end
end
