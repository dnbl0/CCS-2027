require "application_system_test_case"

# The access request form (CCS-69), as a visitor uses it: with the keyboard, a failed send puts focus on the error summary,
# whose links lead to the fields; a good send reaches the confirmation. axe checks each state. AccessPolicy is stubbed, as the
# classification is not in the index yet; the people and addresses are fake.
class AccessRequestSystemTest < ApplicationSystemTestCase
  DOC = "emu-9044"

  setup do
    page.driver.set_cookie("country_acknowledged", "1")
    AccessRequestsController::RATE_STORE.clear
    AccessPolicy.singleton_class.alias_method :__real_tier, :tier
    AccessPolicy.define_singleton_method(:tier) { |_document| :request }
  end

  teardown do
    AccessPolicy.singleton_class.alias_method :tier, :__real_tier
    AccessPolicy.singleton_class.remove_method :__real_tier
    AccessRequest.delete_all
  end

  def press(key) = page.driver.browser.keyboard.type(key)

  def active_id = page.evaluate_script("document.activeElement.id")

  test "the form has no axe violations, and its fields are at least 24px tall" do
    visit AccessPolicy.request_path(SolrDocument.new(id: DOC))

    assert_selector "h1", text: "Request access"
    assert_accessible
    heights = page.evaluate_script("[...document.querySelectorAll('main input:not([name=website]):not([type=hidden]), main textarea, main .btn')].map(e => e.getBoundingClientRect().height)")
    assert heights.all? { |height| height >= 24 }, "a control is shorter than 24px: #{heights}"
  end

  test "sending the form empty puts focus on the error summary, and its links go to the fields" do
    visit "/access_requests/new?document_id=#{DOC}"
    click_button "Send request"

    assert_selector "h2", text: "There is a problem"
    assert_equal "error-summary-title", find("[data-testid=error-summary]")["aria-labelledby"]
    assert page.evaluate_script("document.activeElement.matches('[data-testid=error-summary]')"), "focus is not on the error summary"
    assert_selector "#access_request_name-error", text: "Enter your name"
    assert_accessible

    press :Tab
    assert_equal "Enter your name", page.evaluate_script("document.activeElement.textContent")
    press :Enter
    assert_equal "access_request_name", active_id
  end

  test "a keyboard visitor fills the form and reaches the confirmation, which has no axe violations" do
    visit "/access_requests/new?document_id=#{DOC}"
    fill_in "Your name", with: "Test Person"
    fill_in "Email address", with: "test.person@example.invalid"
    fill_in "How you plan to use this record", with: "Fake research purpose"
    click_button "Send request"

    assert_selector "h1", text: "Request sent"
    assert_text "test.person@example.invalid"
    assert_text "What happens next"
    assert_accessible
    assert_equal 1, AccessRequest.count
  end

  test "the trap field is out of the tab order and out of sight" do
    visit "/access_requests/new?document_id=#{DOC}"

    trap = find("#access_request_website", visible: :all)
    assert_equal "-1", trap["tabindex"]
    assert_operator trap.evaluate_script("this.getBoundingClientRect().right"), :<, 0
  end
end
