require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"

# "Result 3 of 120" at the top of the record's column: Blacklight's search-context pagination, drawn as the approved design draws it
class ResultStepperComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions

  def page = Capybara::Node::Simple.new(rendered_content)

  def doc(id) = SolrDocument.new("id" => id)

  def render_stepper(prev:, nxt:, counter: 3, total: 120)
    with_controller_class(CatalogController) do
      with_request_url("/catalog/emu-3") do
        render_inline(NexusCcs::ResultStepperComponent.new(search_context: { prev: prev, next: nxt },
                                                            search_session: { "document_id" => "emu-3", "id" => 7, "counter" => counter, "total" => total, "per_page" => 20 },
                                                            current_document: doc("emu-3")))
      end
    end
  end

  test "the position and round previous and next links, each named for screen readers" do
    render_stepper(prev: doc("emu-2"), nxt: doc("emu-4"))

    assert_selector "nav.result-stepper[aria-label='Search results'] .result-stepper__position", text: "Result 3 of 120"
    assert_selector "a.result-stepper__step[rel=prev][href*='/catalog/emu-2']", text: "Previous result"
    assert_selector "a.result-stepper__step[rel=next][href*='/catalog/emu-4']", text: "Next result"
  end

  test "the first result keeps the previous button's place, disabled, so the next one does not move" do
    render_stepper(prev: nil, nxt: doc("emu-2"), counter: 1)

    assert_selector ".result-stepper__position", text: "Result 1 of 120"
    assert_selector "span.result-stepper__step[aria-disabled=true]"
    assert_no_selector "a[rel=prev]"
    assert_selector "a[rel=next]"
  end

  test "nothing when the visitor did not arrive from a search" do
    with_request_url("/catalog/emu-3") do
      render_inline(NexusCcs::ResultStepperComponent.new(search_context: nil, search_session: {}, current_document: doc("emu-3")))
    end
    assert_no_selector "nav"
  end
end
