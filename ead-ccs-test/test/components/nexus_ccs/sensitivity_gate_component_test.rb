require "test_helper"

class SensitivityGateComponentTest < ViewComponent::TestCase
  DOC = SolrDocument.new("id" => "emu-1")

  def render_state(state) = render_inline(NexusCcs::SensitivityGateComponent.new(document: DOC, state: state))

  test "ask offers View this item and Do not view as buttons that post the choice" do
    render_state(:ask)

    assert_selector "form[action='/catalog/emu-1/sensitivity'][method=post]", count: 2
    assert_selector "input[name=choice][value=view]", visible: :all
    assert_selector "input[name=choice][value=hide]", visible: :all
    assert_selector "button", text: "View this item"
    assert_selector "button", text: "Do not view"
  end

  test "declined only offers to view, and viewing only to hide" do
    render_state(:declined)
    assert_selector "button", count: 1, text: "View this item"
    assert_text "You chose not to view this item"

    render_state(:viewing)
    assert_selector "button", count: 1, text: "Hide this item"
  end

  test "an unknown state is refused" do
    assert_raises(ArgumentError) { render_state(:other) }
  end
end
