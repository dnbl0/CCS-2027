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

  test "Zoom opens the image in a full-screen modal viewer the keyboard can operate; Escape closes it" do
    visit "/catalog/#{MULTI}"
    assert_no_selector "dialog.media-zoom[open]"
    click_button "Zoom into the image"

    assert_selector "dialog.media-zoom[open] .deep-zoom__stage .openseadragon-canvas", visible: :all
    assert_equal "group", page.evaluate_script("document.querySelector('.deep-zoom__stage .openseadragon-canvas').getAttribute('role')")
    assert_match(/Arrow keys pan/, page.evaluate_script("document.querySelector('.deep-zoom__stage .openseadragon-canvas').getAttribute('aria-label')"))
    assert page.evaluate_script("document.activeElement.matches('.openseadragon-canvas')"), "the image takes focus, so the arrow keys pan at once"
    assert_accessible

    page.send_keys(:escape)
    assert_no_selector "dialog.media-zoom[open]"
    assert_selector ".digital-assets__image", visible: true
  end

  test "Next in the zoom modal opens the next image, and marks it as the one on show" do
    visit "/catalog/#{MULTI}"
    click_button "Zoom into the image"
    assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all
    find("dialog.media-zoom button[aria-label='Next image']").click
    assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all
    assert_match(/image 2 of 2/, page.evaluate_script("document.querySelector('.deep-zoom__stage .openseadragon-canvas').getAttribute('aria-label')"), wait: 5)
    assert_selector ".digital-assets__thumb[aria-current=true][aria-label='Show image 2 of 2']", visible: :all
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
    click_link "Compare this record's images"

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
    click_button "Add to comparison"
    assert_text "Added to comparison"
    visit "/catalog/#{SINGLE}"
    click_button "Add to comparison"
    assert_text "Added to comparison"
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

    assert_no_button "Zoom into the image", visible: :all
    assert_no_button "Add to comparison"
  end
end
