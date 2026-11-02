require "application_system_test_case"

# The record page's "Contact the collection team" card (CCS-47) and its help tips (CCS-101), as a visitor uses them
class RecordContactHelpTest < ApplicationSystemTestCase
  setup do
    page.driver.set_cookie("country_acknowledged", "1")
    visit search_catalog_path(any_assets: "1", q: "skull")
    first(".result-card .document-title-heading a").click
    assert_selector ".contact-collection"
  end

  def press(key) = page.driver.browser.keyboard.type(key)

  def active_label = page.evaluate_script("document.activeElement.textContent.trim()")

  test "the record page, with the contact card and every help tip open, has no axe violations" do
    assert_accessible
    # Opening one tip closes another (focus has left it), so each is checked open on its own
    all("button.help-tip__button").each do |button|
      button.click
      assert_selector "##{button['aria-controls']}", visible: :visible
      assert_accessible
      press(:escape) # closes it before the next, so the page does not shift under the next click
    end
  end

  test "the card names the team and gives a way to write to it, and the controls are at least 24px" do
    within ".contact-collection" do
      assert_selector "h2", text: "Contact the collection team"
      assert_selector "a[href^='mailto:'], a[href^='https://app.smartsheet.com/']"
    end
    sizes = page.evaluate_script("[...document.querySelectorAll('.contact-collection a:not(.help-tip__text a), .help-tip__button')].map(e => { const r = e.getBoundingClientRect(); return [r.width, r.height] })")
    assert sizes.all? { |width, height| width >= 24 && height >= 24 }, "a target is under 24px: #{sizes}"
  end

  test "a help tip opens with the keyboard, Escape closes it and returns focus to its button" do
    button = first("button.help-tip__button")
    page.execute_script("arguments[0].focus()", button)
    press(:enter)
    assert_selector "##{button['aria-controls']}", visible: :visible
    assert_equal "true", button["aria-expanded"]
    assert_selector "##{button['aria-controls']}", visible: :visible

    press(:escape)
    assert_equal "false", button["aria-expanded"]
    assert_no_selector "##{button['aria-controls']}", visible: :visible
    assert_equal button.text(:all), active_label
  end

  test "moving focus away from a tip closes it, and moving into its link keeps it open" do
    button = first("button.help-tip__button")
    button.click
    press(:tab)
    assert_equal "Read more in Help.", active_label
    assert_equal "true", button["aria-expanded"]

    press(:tab)
    assert_equal "false", button["aria-expanded"]
  end
end
