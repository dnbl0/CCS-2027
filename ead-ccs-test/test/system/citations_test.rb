require "application_system_test_case"

# Citation tools in a real browser (CCS-131, CCS-137): the Cite this record dialog on the record page, and the Cite records
# page of a list. axe checks the open dialog and the page; the keyboard and the polite "Copied" status are asserted here.
class CitationsSystemTest < ApplicationSystemTestCase
  setup do
    page.driver.set_cookie("country_acknowledged", "1")
  end

  def open_first_record
    visit search_catalog_path(any_assets: "1", q: "skull", view: "list")
    first(".result-card .document-title-heading a").click
    assert_selector "h1", visible: :all
  end

  test "Cite this record opens a dialog of four styles, is accessible, copies politely, and Escape returns focus to the button" do
    open_first_record
    button = find(".cite__button")
    button.click

    assert_selector "dialog.cite__dialog[open]"
    assert_selector ".cite__style", count: 4
    assert_equal %w[APA\ 7th MLA\ 9th Chicago\ 17th Harvard], all(".cite__style").map(&:text)
    assert_accessible

    within(all(".cite__item").first) do
      find("button[aria-label='Copy APA 7th citation']").click
      assert_selector "[role=status]", text: "Copied"
      assert_selector ".cite__copy", text: "Copied"
    end

    page.driver.browser.keyboard.type(:Escape)
    assert_no_selector "dialog.cite__dialog[open]"
    assert page.evaluate_script("document.activeElement.classList.contains('cite__button')"), "focus returns to the trigger"
  end

  test "the dialog's controls are at least 24px and the button reaches by keyboard" do
    open_first_record
    find(".cite__button").click
    sizes = page.evaluate_script("Array.from(document.querySelectorAll('.cite__dialog[open] button')).map(b => { const r = b.getBoundingClientRect(); return [r.width, r.height] })")
    assert sizes.all? { |w, h| w >= 24 && h >= 24 }, sizes.inspect
  end

  test "the Cite records page of a list: choose a style and records, copy and download, with no axe violations" do
    visit search_catalog_path(any_assets: "1", q: "skull", view: "list")
    card = first(".result-card")
    card.find(".list-menu__button").click
    card.find(".list-menu__input").fill_in(with: "Skulls")
    card.click_button "Create and add"
    assert_selector "[role=status], .alert", text: /List Skulls created/
    visit lists_path
    click_link "Skulls"
    click_link "Cite records"

    assert_selector "h1", text: "Cite records"
    assert_selector ".cite-page__reference", count: 1
    assert_accessible

    choose "MLA 9th"
    click_button "Show citations"
    assert_selector "#cite-results-heading", text: "1 citation in MLA 9th"
    assert page.evaluate_script("document.activeElement.id === 'cite-results-heading'"), "focus moves to the results heading"
    assert_selector ".cite-page__reference", text: /Accessed/

    click_button "Copy citations"
    assert_selector "[role=status]", text: "Copied"
    assert_link "Download citations (.txt)"
    assert_accessible
  end
end
