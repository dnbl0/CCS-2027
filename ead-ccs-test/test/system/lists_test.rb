require "application_system_test_case"

# Named lists in a real browser (CCS-389): the Add to list disclosure on a result card, making a list from it, the
# lists pages, and the delete confirmation. axe checks each page and the open menu.
class ListsSystemTest < ApplicationSystemTestCase
  setup do
    page.driver.set_cookie("country_acknowledged", "1")
  end

  def card_menu(card) = card.find(".list-menu")

  test "Add to list is a disclosure: it opens on Enter, keeps focus on its button, and Escape closes it and returns focus" do
    visit search_catalog_path(any_assets: "1", q: "skull", view: "list")
    card = first(".result-card")
    button = card.find(".list-menu__button")

    assert_equal "false", button["aria-expanded"]
    assert_no_selector ".list-menu__panel", visible: :visible
    assert_match(/\AAdd to list: /, button.text(:all).squish)

    button.execute_script("this.focus()")
    page.driver.browser.keyboard.type(:Enter)
    assert_equal "true", button["aria-expanded"]
    assert_selector ".list-menu__panel", visible: :visible
    assert page.evaluate_script("document.activeElement.classList.contains('list-menu__button')"), "focus stays on the button"
    assert_accessible

    card.find(".list-menu__input").execute_script("this.focus()")
    page.driver.browser.keyboard.type(:Escape)
    assert_equal "false", button["aria-expanded"]
    assert page.evaluate_script("document.activeElement.classList.contains('list-menu__button')"), "Escape returns focus to the button"
  end

  test "a list is made from a result card, the record added to others, listed, renamed and deleted after a confirmation" do
    visit search_catalog_path(any_assets: "1", q: "skull", view: "list")
    card = first(".result-card")
    title = card.find(".document-title-heading a").text
    card.find(".list-menu__button").click
    card.find(".list-menu__input").fill_in(with: "Skulls")
    card.click_button "Create and add"

    assert_text "List Skulls created, and the record added to it."
    card = first(".result-card")
    card.find(".list-menu__button").click
    assert_selector ".list-menu__item--in", text: "Remove from Skulls"

    click_link "Saved records" if false # the header bar is a link to /bookmarks; the lists page is reached from there
    visit lists_path
    assert_selector "h1", text: "Your lists"
    assert_selector "table.lists tbody tr", count: 1
    assert_accessible
    click_link "Skulls"
    assert_selector "h1", text: "Skulls"
    assert_selector ".result-card .document-title-heading", text: title
    assert_accessible

    click_link "Rename"
    fill_in "List name", with: ""
    click_button "Save name"
    assert_selector ".alert", text: /can.t be blank/
    assert page.evaluate_script("document.activeElement.classList.contains('alert')"), "focus moves to the error summary"
    assert_accessible
    fill_in "List name", with: "Bones"
    click_button "Save name"
    assert_selector "h1", text: "Bones"

    # declining the confirmation keeps the list
    dismiss_confirm { click_button "Delete" }
    assert_selector "h1", text: "Bones"
    accept_confirm { click_button "Delete" }
    assert_text "List Bones deleted."
    assert_selector "h2", text: "0 lists"
    assert page.evaluate_script("document.activeElement.tagName === 'H2'"), "focus lands on the count after a delete"
    assert_accessible
  end
end
