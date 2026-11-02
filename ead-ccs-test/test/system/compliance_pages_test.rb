require "application_system_test_case"

# The accessibility statement, the privacy notice and Delete my data (CCS-148), in a real browser with axe.
class CompliancePagesTest < ApplicationSystemTestCase
  setup { page.driver.set_cookie("country_acknowledged", "1") }

  { "accessibility statement" => "/accessibility", "privacy notice" => "/privacy", "Delete my data (nothing held)" => "/my_data" }.each do |name, path|
    test "the #{name} has no axe violations (WCAG 2.2 AA and best practice), one h1 and a skip link target" do
      visit path

      assert_selector "h1", count: 1
      assert_selector "main#main-content"
      assert_accessible tags: AXE_TAGS + WCAG22_TAGS
    end
  end

  test "the footer's two statements open the pages" do
    visit "/help"
    within(".site-footer__legal") { click_link "Accessibility of this site" }
    assert_selector "h1", text: "Accessibility of Collections Navigator"
    within(".site-footer__legal") { click_link "Privacy and data on this site" }
    assert_selector "h1", text: "Privacy and data on Collections Navigator"
  end

  test "a visitor with saved items sees them listed, confirms with the button, and ends with nothing held" do
    visit "/lists/new"
    fill_in "List name", with: "Teaching"
    click_button "Create list"
    assert_text "Teaching"

    visit "/privacy"
    click_link "Delete my data"
    assert_selector "h1", text: "Delete my data"
    assert_text "1 list"
    assert_text "Requests for access to a record are not removed here"
    assert_accessible

    click_button "Delete my data"
    assert_text "Your data has been deleted from this site."
    assert_text "There is nothing to delete"
    assert_selector "button[disabled]", text: "Delete my data"
    assert_equal 0, List.count
    assert_accessible
  end

  def first_id(filter)
    Blacklight.default_index.connection.get("select", params: { q: "*:*", fq: filter, rows: 1, fl: "id", wt: "json" }).dig("response", "docs", 0, "id")
  end

  test "an ICIP record shows the cultural protocols notice, and a record with no rights says none is recorded, both with no axe violations" do
    visit "/catalog/#{first_id('licence_type_ssim:"ICIP Rights"')}"
    assert_selector "aside.record-cultural-protocols h2", text: "Cultural protocols apply to this record"
    assert_accessible tags: AXE_TAGS + WCAG22_TAGS

    visit "/catalog/#{first_id('-licence_type_ssim:[* TO *] AND -rights_ssim:[* TO *] AND -credit_line_tsim:[* TO *]')}"
    assert_selector ".record-copyright__none", text: "No licence or rights statement is recorded"
    assert_accessible tags: AXE_TAGS + WCAG22_TAGS
  end
end
