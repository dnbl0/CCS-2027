require "application_system_test_case"

# CCS-227 (sensitive assets), CCS-163 (metadata CSV) and CCS-167 (bulk download) in a real browser, with axe over each state.
class SensitivityExportDownloadTest < ApplicationSystemTestCase
  OPEN = "emu-9044"

  setup { page.driver.set_cookie("country_acknowledged", "1") }

  # Makes OPEN sensitive for the block (the server runs in this process). Minitest 6 has no stub.
  def sensitive
    original = Sensitivity.method(:sensitive?)
    Sensitivity.define_singleton_method(:sensitive?) { |document| document.id == OPEN }
    yield
  ensure
    Sensitivity.define_singleton_method(:sensitive?, original)
  end

  def focused_text = page.evaluate_script("document.activeElement.textContent").to_s.squish

  test "a sensitive record asks first: no image, two buttons, accessible; View this item shows it and focus lands on the notice" do
    sensitive do
      visit solr_document_path(OPEN)

      assert_selector ".sensitivity-gate--ask", text: "This item may contain sensitive material"
      assert_no_selector ".digital-assets img"
      assert_selector "button", text: "View this item"
      assert_selector "button", text: "Do not view"
      assert_accessible

      click_button "View this item"
      assert_selector ".digital-assets img.digital-assets__image"
      assert_selector ".sensitivity-gate--viewing"
      assert_match(/You chose to view it/, focused_text)
      assert_accessible

      click_button "Hide this item"
      assert_selector ".sensitivity-gate--declined"
      assert_no_selector ".digital-assets img"
      assert_match(/You chose not to view this item/, focused_text)
      assert_accessible
    end
  end

  test "Do not view keeps the image hidden, and the keyboard can reach and press the buttons" do
    sensitive do
      visit solr_document_path(OPEN)
      click_button "Do not view"

      assert_selector ".sensitivity-gate--declined"
      assert_no_selector ".digital-assets img"
      page.find("button", text: "View this item").execute_script("this.focus()")
      page.driver.browser.keyboard.type(:Enter)
      assert_selector ".digital-assets img.digital-assets__image"
    end
  end

  test "an open record offers Download metadata (CSV) as a link, and the page has no axe violations" do
    visit solr_document_path(OPEN)

    assert_selector "a[href='/catalog/#{OPEN}/metadata']", text: "Download metadata (CSV)"
    assert_accessible
  end

  test "choose records on the saved page, review the download, and the review page is accessible" do
    visit solr_document_path(OPEN)
    find(".toggle-bookmark-label").click
    assert_selector ".toggle-bookmark-label.checked"

    visit bookmarks_path
    find("summary", text: "Download digital assets").click
    assert_selector "fieldset legend", text: "Choose the records to download"
    assert_accessible

    check_box = find("input[name='ids[]'][value='#{OPEN}']")
    check_box.click
    click_button "Review download"

    assert_selector "h1", text: "Download digital assets"
    assert_selector "h2", text: /1 record will be downloaded/
    assert_selector "input[type=submit][value^='Download zip file']"
    assert_accessible
  end

  test "reviewing with nothing chosen shows the message on the saved page" do
    visit solr_document_path(OPEN)
    find(".toggle-bookmark-label").click
    assert_selector ".toggle-bookmark-label.checked"
    visit bookmarks_path
    find("summary", text: "Download digital assets").click
    click_button "Review download"

    assert_text "Choose at least one record to download."
    assert_accessible
  end
end
