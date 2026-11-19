require "application_system_test_case"

# Saving records through Blacklight's bookmark toggle, in a real browser, with no login.
class SavedRecordsTest < ApplicationSystemTestCase
  setup do
    page.driver.set_cookie("country_acknowledged", "1")
  end

  def bar = find(".site-nav__saved-text")

  test "Save becomes Saved without a reload, the header count follows, and the list page shows the record" do
    visit search_catalog_path(any_assets: "1", q: "skull", view: "list")
    assert_selector ".site-nav__saved--empty"
    assert_text "0 saved records"
    page.execute_script("window.sameDocument = true")

    card = first(".result-card")
    title = card.find(".document-title-heading a").text
    within(card) do
      assert_selector ".toggle-bookmark-label", text: /\ASave\s+record: #{Regexp.escape(title)}\z/
      find(".toggle-bookmark-label").click
      assert_selector ".toggle-bookmark-label.checked", text: /\ASaved\s+record: #{Regexp.escape(title)}\z/
    end

    assert_selector ".site-nav__saved:not(.site-nav__saved--empty)"
    assert_equal "1 saved record", bar.text
    assert page.evaluate_script("window.sameDocument"), "the page reloaded"

    # the second card makes it plural
    all(".result-card")[1].find(".toggle-bookmark-label").click
    assert_text "2 saved records"

    click_link "2 saved records"
    assert_current_path "/bookmarks"
    assert_selector "h1", text: "Saved records"
    assert_selector ".saved-main .result-card", count: 2
    assert_selector ".saved-toolbar__count", text: "2 saved records"

    # toggling again on the list removes it from the saved list and the count follows
    first(".saved-main .toggle-bookmark-label").click
    assert_text "1 saved record"
    visit bookmarks_path
    assert_selector ".saved-main .result-card", count: 1
  end

  # Save on a result card toggles in place in both views and never opens the record, by pointer or keyboard.
  %w[masonry list].each do |view|
    test "Save on a #{view} card toggles in place without leaving the results (click, Space, Enter)" do
      visit search_catalog_path(any_assets: "1", q: "skull", view: view)
      results_url = current_url
      page.execute_script("window.sameDocument = true")

      # a real pointer click at the label's centre, so anything laid over it (the mosaic's stretched title link) takes the click
      first(".result-card .toggle-bookmark-label").execute_script("this.scrollIntoView({ block: 'center' })")
      pt = page.evaluate_script("(function () { var r = document.querySelector('.result-card .toggle-bookmark-label').getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; })()")
      page.driver.browser.mouse.click(x: pt[0], y: pt[1])
      assert_selector ".result-card:nth-of-type(1) .toggle-bookmark-label.checked", text: /Saved/
      assert_text "1 saved record"

      [ [ 1, :Space ], [ 2, :Enter ] ].each_with_index do |(index, key), n|
        box = all(".result-card")[index].find(".save-control__input", visible: :all)
        box.execute_script("this.focus()")
        page.driver.browser.keyboard.type(key)
        assert_selector ".result-card:nth-of-type(#{index + 1}) .toggle-bookmark-label.checked", text: /Saved/
        assert_text "#{n + 2} saved records"
      end

      assert_equal results_url, current_url
      assert page.evaluate_script("window.sameDocument"), "the page navigated"
    end
  end

  # The bar is exactly as tall as the breadcrumb strip and flush to its top, bottom and right edge, at every width.
  test "the saved bar fills the breadcrumb strip at 1440, 1000 and 390 wide" do
    [ [ 1440, 900 ], [ 1000, 800 ], [ 390, 844 ] ].each do |width, height|
      page.driver.resize(width, height)
      [ search_catalog_path(any_assets: "1", q: "skull"), bookmarks_path, about_path ].each do |path|
        visit path
        assert_selector ".breadcrumb-strip a.site-nav__saved"
        box = page.evaluate_script(<<~JS)
          (function () {
            var strip = document.querySelector(".breadcrumb-strip").getBoundingClientRect();
            var bar = document.querySelector(".breadcrumb-strip .site-nav__saved").getBoundingClientRect();
            return { strip: strip.height, bar: bar.height, top: bar.top - strip.top, right: strip.right - bar.right, edge: document.documentElement.clientWidth - bar.right };
          })()
        JS
        label = "#{width}px #{path}"
        assert_in_delta box["strip"], box["bar"], 0.5, "#{label}: bar height #{box["bar"]} vs strip #{box["strip"]}"
        assert_operator box["bar"], :>=, 44, label
        assert_in_delta 0, box["top"], 0.5, label
        assert_in_delta 0, box["right"], 0.5, label
        assert_in_delta 0, box["edge"], 0.5, label
      end
    end
  ensure
    page.driver.resize(1440, 900)
  end

  test "the saved bar has aria-current on the saved list and a visible focus ring" do
    visit bookmarks_path
    assert_selector ".breadcrumb-strip a.site-nav__saved[aria-current=page]"

    find(".breadcrumb-strip a.site-nav__saved").execute_script("this.focus()")
    shadow = page.evaluate_script("getComputedStyle(document.querySelector('.breadcrumb-strip .site-nav__saved')).boxShadow")
    assert_not_equal "none", shadow
  end

  test "the home page has the bar over the top right of the hero photo, not in the header strip" do
    visit root_path
    assert_selector ".ccs-hero__media a.site-nav__saved--hero", count: 1
    assert_no_selector ".site-header__utility a.site-nav__saved"
    assert_no_selector ".breadcrumb-strip"
  end

  test "on phones the home page menu has a saved-records link; desktop and other pages do not" do
    visit root_path
    assert_no_selector "a.site-nav__saved--drawer"

    page.driver.resize(390, 844)
    visit root_path
    find(".site-header__menu").click
    within("#site-nav") do
      assert_selector "a.site-nav__saved--drawer", text: "0 saved records"
      click_link "0 saved records"
    end
    assert_current_path bookmarks_path

    visit about_path
    find(".site-header__menu").click
    assert_no_selector "#site-nav a.site-nav__saved--drawer", visible: :all
  ensure
    page.driver.resize(1440, 900)
  end

  test "the record page control is a real checkbox that takes keyboard focus, and the count survives navigation" do
    visit search_catalog_path(any_assets: "1", q: "skull", view: "list")
    visit first(".result-card .document-title-heading a")[:href]

    checkbox = find(".record-actions__row .save-control__input", visible: :all)
    checkbox.execute_script("this.focus()")
    assert page.evaluate_script("document.activeElement.matches('.record-actions__row input[type=checkbox]')")
    assert_selector ".record-actions__row .toggle-bookmark-label:has(:focus-visible)"

    find(".record-actions__row .toggle-bookmark-label").click
    assert_selector ".record-actions__row .toggle-bookmark-label.checked", text: "Saved"
    assert_text "1 saved record"

    visit root_path
    assert_text "1 saved record"
    assert_selector ".site-nav__saved:not(.site-nav__saved--empty)"
  end

  test "the saved list and the bar have no accessibility violations" do
    visit search_catalog_path(any_assets: "1", q: "skull", view: "list")
    first(".result-card .toggle-bookmark-label").click
    assert_text "1 saved record"
    assert_accessible

    visit bookmarks_path
    assert_selector ".saved-main .result-card"
    assert_accessible
  end
end
