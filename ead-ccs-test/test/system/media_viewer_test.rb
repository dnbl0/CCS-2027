require "application_system_test_case"

# CCS-57, CCS-58: zoom and pan on the record page, and comparing images side by side. Against the Solr core's records:
# emu-407750 is :open with two images, emu-406126 is :open with one.
class MediaViewerTest < ApplicationSystemTestCase
  MULTI = "emu-407750"
  SINGLE = "emu-406126"

  setup do
    needs_solr
    page.driver.set_cookie("country_acknowledged", "1")
  end

  teardown { page.current_window.resize_to(1440, 900) }

  def needs_solr
    Blacklight.default_index.connection.get("select", params: { q: "*:*", rows: 0 })
  rescue StandardError
    skip "needs the Solr core at SOLR_URL"
  end

  def sideways_scroll = page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")

  test "Zoom and pan swaps the image for a viewer that the keyboard can operate, and closing it puts the image back" do
    visit "/catalog/#{MULTI}"
    assert_no_selector ".deep-zoom__stage", visible: true
    click_button "Zoom and pan"

    assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all
    assert_selector "button[aria-pressed=true]", text: "Zoom and pan"
    assert_no_selector ".digital-assets__image", visible: true
    assert_equal "group", page.evaluate_script("document.querySelector('.deep-zoom__stage .openseadragon-canvas').getAttribute('role')")
    assert_match(/Arrow keys pan/, page.evaluate_script("document.querySelector('.deep-zoom__stage .openseadragon-canvas').getAttribute('aria-label')"))
    assert page.evaluate_script("document.activeElement === document.querySelector('.deep-zoom__stage .openseadragon-canvas')"), "focus moves into the viewer"

    click_button "Zoom in"
    click_button "Zoom out"
    click_button "Reset view"
    assert_accessible

    click_button "Zoom and pan"
    assert_selector ".digital-assets__image", visible: true
    assert_equal "false", find_button("Zoom and pan")["aria-pressed"]
    assert page.evaluate_script("document.activeElement === document.querySelector('.deep-zoom__toggle')"), "focus returns to the toggle"
  end

  test "the mouse wheel over the zoom viewer is left to the page: no zoom, and no scroll trap" do
    visit "/catalog/#{MULTI}"
    click_button "Zoom and pan"
    assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all

    # dispatchEvent returns false when something called preventDefault on the event
    not_prevented = page.evaluate_script("document.querySelector('.deep-zoom__stage .openseadragon-canvas').dispatchEvent(new WheelEvent('wheel', { deltaY: 200, bubbles: true, cancelable: true }))")
    assert not_prevented, "the viewer swallows the mouse wheel over a zoomed picture"
  end

  test "the thumbnail of another image opens it in the viewer when zoom is on" do
    visit "/catalog/#{MULTI}"
    click_button "Zoom and pan"
    assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all
    all(".digital-assets__other")[1].click # the strip lists every image, the current one first
    assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all
    assert_match(/image 2 of 2/, page.evaluate_script("document.querySelector('.deep-zoom__stage .openseadragon-canvas').getAttribute('aria-label')"))
  end

  def pane_zoom(index) = page.evaluate_script("Number(document.querySelectorAll('.compare-pane')[#{index}].dataset.zoom || 0)")

  def wait_for_zoom_to_settle
    previous = nil
    Timeout.timeout(5) do
      loop do
        now = [ pane_zoom(0), pane_zoom(1) ]
        break if now == previous

        previous = now
        sleep 0.3
      end
    end
  end

  test "Compare images: two panes with synchronised zoom, a selector each, and the link can be switched off" do
    visit "/catalog/#{MULTI}"
    click_link "Compare images"

    assert_selector ".compare.is-ready"
    assert_selector ".compare-pane", count: 2
    assert_selector ".compare-pane .openseadragon-canvas", count: 2, visible: :all
    assert_checked_field "Link zoom and pan"
    assert_accessible

    first(".compare-pane button", text: "Zoom in").click
    wait_for_zoom_to_settle
    assert_in_delta pane_zoom(0), pane_zoom(1), 0.001, "linked panes zoom together"

    uncheck "Link zoom and pan"
    first(".compare-pane button", text: "Zoom in").click
    wait_for_zoom_to_settle
    assert_operator pane_zoom(0), :>, pane_zoom(1)

    all(".compare-pane select").first.select "Image 2 of 2"
    assert_match(/image 2 of 2/, page.evaluate_script("document.querySelector('.compare-pane [data-pane-image-name]').textContent"))
  end

  test "the keyboard can reach and operate a pane: focus in the viewer, = zooms, 0 resets; every control has a name" do
    visit "/compare?record=#{MULTI}"
    assert_selector ".compare.is-ready"

    page.evaluate_script("document.querySelector('.compare-pane .openseadragon-canvas').focus()")
    assert_operator pane_zoom(0), :>, 0
    start = pane_zoom(0)
    page.driver.browser.keyboard.type("=")
    sleep 1.2
    assert_operator pane_zoom(0), :>, start, "the equals key zooms in"
    page.driver.browser.keyboard.type("0")
    sleep 1.2
    assert_in_delta start, pane_zoom(0), 0.01, "0 resets"

    unnamed = page.evaluate_script("Array.from(document.querySelectorAll('.compare-pane button, .compare-pane select, .compare-pane .openseadragon-canvas')).filter(function (e) { return !(e.getAttribute('aria-label') || e.textContent.trim() || (e.labels && e.labels.length)) }).length")
    assert_equal 0, unnamed
    assert_selector ".compare-pane button", text: "Full screen", count: 2
  end

  test "records from different pages are compared once added; each pane has its title, accession number and licence" do
    visit "/catalog/#{MULTI}"
    click_button "Add to compare"
    assert_text "Added to compare"
    visit "/catalog/#{SINGLE}"
    click_button "Add to compare"
    assert_text "Added to compare"
    click_link "Open comparison (2)"

    assert_selector ".compare-pane", count: 2
    assert_selector ".compare-pane .compare-pane__details dt", text: "Licence", count: 2
    assert_selector ".compare-pane .compare-pane__details dt", text: "Accession number", count: 2
    assert_selector ".compare.is-ready"
    assert_accessible

    first(".compare-pane button", text: "Remove").click
    assert_selector ".compare-pane", count: 1
    assert_text "Add one more record to compare"
  end

  test "at 320px the panes stack, nothing scrolls sideways and the page has no accessibility violations" do
    page.current_window.resize_to(320, 800)
    visit "/compare?record=#{MULTI}"
    assert_selector ".compare.is-ready"

    tops = page.evaluate_script("Array.from(document.querySelectorAll('.compare-pane')).map(function (p) { return Math.round(p.getBoundingClientRect().top) })")
    assert_operator tops[1], :>, tops[0], "the second pane is under the first"
    assert_operator sideways_scroll, :<=, 0
    heights = page.evaluate_script("Array.from(document.querySelectorAll('.compare-pane__stage')).map(function (s) { return s.getBoundingClientRect().height })")
    assert_operator heights.min, :>, 100
    assert_accessible
  end

  test "the panes hold their size when the viewers start: nothing shifts" do
    visit "/compare?record=#{MULTI}"
    before = page.evaluate_script("Array.from(document.querySelectorAll('.compare-pane')).map(function (p) { return p.getBoundingClientRect().height })")
    assert_selector ".compare.is-ready"
    after = page.evaluate_script("Array.from(document.querySelectorAll('.compare-pane')).map(function (p) { return p.getBoundingClientRect().height })")
    before.zip(after).each { |was, now| assert_in_delta was, now, 2 }
  end

  test "a withheld record offers no zoom and no compare" do
    needs_solr
    withheld = Blacklight.default_index.connection.get("select", params: { q: "licence_type_ssim:\"ICIP Rights\"", rows: 1, fl: "id" }).dig("response", "docs", 0, "id")
    skip "no withheld record in the index" unless withheld
    visit "/catalog/#{withheld}"

    assert_no_button "Zoom and pan"
    assert_no_button "Add to compare"
  end
end
