require "application_system_test_case"

# Galleries, the share dialog and the embed pages in a real browser: axe at desktop and 320px, the keyboard path, and the polite
# "Copied" announcement.
class SharingSystemTest < ApplicationSystemTestCase
  setup do
    page.driver.set_cookie("country_acknowledged", "1")
    needs_solr
  end

  def shared_list
    list = User.create!.lists.create!(name: "Strings", description: "Instruments we like")
    %w[emu-400198 emu-400205 emu-400001].each { |id| list.list_items.create!(document_id: id) }
    list.share!
  end

  def at_sizes
    [ [ 1440, 900 ], [ 320, 700 ] ].each do |width, height|
      page.driver.resize(width, height)
      yield width
    end
  ensure
    page.driver.resize(1440, 900)
  end

  test "the shared gallery is accessible, has no owner, and does not scroll sideways at 320px" do
    list = shared_list
    at_sizes do |width|
      visit "/galleries/#{list.share_token}"
      assert_selector "h1", text: "Strings"
      assert_selector ".result-card", count: 3
      assert_button "Add to my list"
      assert_accessible tags: AXE_TAGS + WCAG22_TAGS, except: %w[heading-order]
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, width, "no horizontal scroll at #{width}px"
    end
  end

  test "the share dialog opens from the keyboard, copies politely, is accessible and returns focus on Escape" do
    list = shared_list
    visit "/galleries/#{list.share_token}"
    button = find(".share__button")
    button.execute_script("this.focus()")
    page.driver.browser.keyboard.type(:Enter)

    assert_selector "dialog.share__dialog[open]"
    assert_selector "textarea.share__code", count: 2
    at_sizes { assert_accessible tags: AXE_TAGS + WCAG22_TAGS, except: %w[heading-order] }

    within("dialog.share__dialog") do
      first(:button, "Copy link").click
      assert_selector "[role=status]", text: "Copied"
      click_button "Copy fixed size code"
      assert_selector ".cite__copy", text: "Copied"
    end
    page.driver.browser.keyboard.type(:Escape)
    assert_no_selector "dialog[open]"
    assert page.evaluate_script("document.activeElement.classList.contains('share__button')"), "focus returns to the button"
  end

  test "the owner's share dialog creates the link and opens with it" do
    visit "/lists/new"
    fill_in "List name", with: "Mine"
    click_button "Create list"
    click_button "Share this list"
    within("dialog[open]") { click_button "Create share link" }

    assert_selector "dialog[open] input[readonly][value*='/galleries/']"
    assert_selector ".share-status", text: /Anyone with the link/
    assert_accessible tags: AXE_TAGS + WCAG22_TAGS, except: %w[heading-order]
  end

  test "an embed page is accessible at desktop and 320px" do
    list = shared_list
    [ "/embed/records/emu-400198", "/embed/galleries/#{list.share_token}" ].each do |path|
      at_sizes do |width|
        visit path
        assert_selector "h1"
        assert_accessible tags: AXE_TAGS + WCAG22_TAGS
        assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, width, "#{path} scrolls sideways at #{width}px"
      end
    end
  end

  test "the record page's Share and embed dialog is accessible" do
    visit "/catalog/emu-400198"
    click_button "Share and embed"
    assert_selector "dialog.share__dialog[open]"
    assert_accessible tags: AXE_TAGS + WCAG22_TAGS, except: %w[heading-order]
  end
end
