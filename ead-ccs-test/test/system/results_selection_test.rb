require "application_system_test_case"

# CCS-39 and CCS-40 in a browser, against the Solr core at SOLR_URL: the rationale on the cards, and choosing results by
# keyboard with the count announced in a polite status region. axe checks the page in each state.
class ResultsSelectionTest < ApplicationSystemTestCase
  setup do
    page.driver.set_cookie("country_acknowledged", "1")
    page.driver.resize(1400, 1000)
  end

  def press(key) = page.driver.browser.keyboard.type(key)

  # Waits for the status to say it (the count is written by a script after the key press)
  def assert_status(text) = assert_selector("#selection-form [role=status]", exact_text: text)

  def focus_on(selector)
    page.execute_script("document.querySelector(#{selector.to_json}).focus()")
  end

  def visit_results(params = {})
    visit search_catalog_path({ q: "skull", any_assets: "1", view: "list", per_page: 12 }.merge(params))
    assert_selector ".result-card", minimum: 12
  end

  # --- CCS-39 ---

  test "each card says where the words matched, marks them, and the page has no axe violations" do
    visit_results

    assert_selector ".result-card__matched", text: /\AMatched in: Title/, minimum: 1
    assert_selector ".document-title-heading a mark", text: /skull/i, minimum: 1
    assert_selector ".result-card__snippet mark", minimum: 1
    assert_accessible
  end

  test "the matched words are marked with a contrast of at least 4.5 to 1 against their background, and are underlined" do
    visit_results
    style = page.evaluate_script(<<~JS)
      (() => {
        const mark = document.querySelector(".result-card mark")
        const css = getComputedStyle(mark)
        return { background: css.backgroundColor, color: css.color, underline: css.textDecorationLine }
      })()
    JS
    ratio = contrast(style["color"], style["background"])

    assert_includes style["underline"], "underline"
    assert_operator ratio, :>=, 4.5, "mark text #{style["color"]} on #{style["background"]}"
  end

  test "an Advanced search row, a phrase and a wildcard are marked" do
    visit search_catalog_path(any_assets: "1", view: "list", clause: { "0" => { field: "title", op: "must", query: "skull" } })
    assert_selector ".document-title-heading a mark", text: /skull/i, minimum: 1

    visit search_catalog_path(any_assets: "1", view: "list", q: '"human skull"')
    assert_selector ".document-title-heading a mark", text: /human skull/i, minimum: 1

    visit search_catalog_path(any_assets: "1", view: "list", q: "skul*")
    assert_selector ".document-title-heading a mark", text: /skul/i, minimum: 1
  end

  # --- CCS-40 ---

  test "a checkbox on each card is named by the record, and ticking one by keyboard announces the new count" do
    visit_results
    first_title = first(".result-card .document-title-heading a").text
    assert_status "No records selected"

    focus_on(".result-card__select-input")
    press(:space)
    assert_status "1 record selected"
    assert_equal "Select: #{first_title}", accessible_name(".result-card__select-input:checked").sub(" :", ":")

    page.execute_script("document.querySelectorAll('.result-card__select-input')[1].focus()")
    press(:space)
    assert_status "2 records selected"
    assert_link "View selected (2)"
  end

  test "the status region is polite, atomic and present before anything changes" do
    visit_results

    region = find("#selection-form p[role=status]")
    assert_equal "polite", region["aria-live"]
    assert_equal "true", region["aria-atomic"]
  end

  test "Select all on this page and Clear selection work, and the selection page lists only those records, in order" do
    visit_results
    click_button "Select all on this page"
    assert_status "12 records selected"
    assert_selector ".result-card__select-input:checked", count: 12

    click_button "Clear selection"
    assert_status "No records selected"
    assert_selector ".result-card__select-input:checked", count: 0

    boxes = all(".result-card__select-input", minimum: 3)
    titles = all(".result-card .document-title-heading a").map(&:text)
    [ 2, 0, 1 ].each { |index| boxes[index].click }
    assert_status "3 records selected"

    click_link "View selected (3)"
    assert_selector "h2", text: "3 selected records"
    assert_equal [ titles[2], titles[0], titles[1] ], all(".result-card .document-title-heading a").map(&:text)
    assert_accessible
  end

  test "the selection stays across pages of results and reloads, and a tick that is refused when it is full is undone" do
    visit_results(per_page: 96)
    click_button "Select all on this page"
    assert_text "You can select up to 50 records" # 96 on the page, 50 at most
    assert_selector ".result-card__select-input:checked", count: 50

    visit_results(per_page: 96)
    assert_status "50 records selected"
    assert_selector ".result-card__select-input:checked", count: 50

    unticked = all(".result-card__select-input:not(:checked)", minimum: 1).first
    unticked.click
    assert_text "You can select up to 50 records"
    assert_selector ".result-card__select-input:checked", count: 50
  end

  test "a record in the selection offers previous and next selected record, and the selection can be cited" do
    visit_results
    boxes = all(".result-card__select-input", minimum: 3)
    boxes.first(3).each(&:click)
    assert_status "3 records selected"

    click_link "View selected (3)"
    all(".result-card .document-title-heading a").first.click
    assert_selector "nav.selection-stepper", text: "Selected record 1 of 3"
    click_link "Next selected record"
    assert_selector "nav.selection-stepper", text: "Selected record 2 of 3"
    assert_accessible

    click_link "All selected records"
    click_link "Cite selected records"
    assert_selector ".cite-page__reference", count: 3
  end

  test "a phone sees the bar and the cards without scrolling sideways" do
    page.driver.resize(360, 800)
    visit_results
    assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end

  test "the checkbox and the buttons are at least 24 by 24 pixels" do
    visit_results
    sizes = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(".result-card__select-input, .result-card__select-label, #selection-form button, #selection-form a"))
        .filter((el) => el.offsetParent !== null)
        .map((el) => { const r = el.getBoundingClientRect(); return [el.className, r.width, r.height] })
    JS
    small = sizes.select { |_, width, height| width < 24 || height < 24 }

    assert_empty small
  end

  private

  def accessible_name(selector)
    first(selector).execute_script("this.setAttribute('data-name-probe', '')")
    cdp = page.driver.browser.page
    root = cdp.command("DOM.getDocument", depth: 0)["root"]["nodeId"]
    node = cdp.command("DOM.querySelector", nodeId: root, selector: "[data-name-probe]")["nodeId"]
    page.execute_script("document.querySelector('[data-name-probe]').removeAttribute('data-name-probe')")
    cdp.command("Accessibility.getPartialAXTree", nodeId: node, fetchRelatives: false)["nodes"].first.dig("name", "value").to_s.squish
  end

  # WCAG contrast ratio of two "rgb(r, g, b)" or "rgba(...)" colours (the second is the background; an alpha is ignored)
  def contrast(foreground, background)
    light = ->(css) do
      channels = css.scan(/\d+(?:\.\d+)?/).first(3).map { |value| value.to_f / 255 }.map { |c| c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }
      (0.2126 * channels[0]) + (0.7152 * channels[1]) + (0.0722 * channels[2])
    end
    lighter, darker = [ light.call(foreground), light.call(background) ].minmax.reverse
    (lighter + 0.05) / (darker + 0.05)
  end
end
