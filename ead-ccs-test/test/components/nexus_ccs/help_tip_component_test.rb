require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

# Contextual help text (CCS-101): a toggletip whose text is in the page, not hover-only
class HelpTipComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  def page = Capybara::Node::Simple.new(rendered_content)

  test "a button names its topic and controls the help text, which starts hidden" do
    render_inline(NexusCcs::HelpTipComponent.new(topic: :persistent_link))

    assert_selector "span[data-controller=help-tip] button[type=button][aria-expanded=false]", text: "About persistent links"
    id = page.find("button")[:"aria-controls"]
    assert_selector "##{id}[hidden]", visible: :all, text: /always leads back to this record/
  end

  test "the text has a link to the matching section of Help" do
    render_inline(NexusCcs::HelpTipComponent.new(topic: :copyright))

    assert_selector "a[href='/help#copyright']", text: /Read more in Help/, visible: :all
  end

  test "the visible label is in the accessible name" do
    render_inline(NexusCcs::HelpTipComponent.new(topic: :copyright))

    button = page.find("button")
    assert_equal button.text.strip, button.find(".help-tip__label").text.strip
    assert_nil button[:"aria-label"]
  end

  test "two tips on a page have different ids" do
    render_inline(NexusCcs::HelpTipComponent.new(topic: :copyright))
    first = page.find("button")[:"aria-controls"]
    render_inline(NexusCcs::HelpTipComponent.new(topic: :persistent_link))
    refute_equal first, page.find("button")[:"aria-controls"]
  end

  test "an unknown topic is an error, not an empty tip" do
    assert_raises(KeyError) { render_inline(NexusCcs::HelpTipComponent.new(topic: :nope)) }
  end
end
