require "application_system_test_case"

# WCAG 1.4.10 Reflow: a record page with a digital asset fits a 390px phone without scrolling sideways, with the record column's
# Media details section closed, open, and closed again.
class RecordMediaReflowTest < ApplicationSystemTestCase
  setup do
    page.driver.set_cookie("country_acknowledged", "1")
    page.current_window.resize_to(390, 844)
  end

  teardown { page.current_window.resize_to(1400, 900) }

  def page_width = page.evaluate_script("[document.documentElement.scrollWidth, document.documentElement.clientWidth]")

  def assert_no_sideways_scroll(state)
    scroll, client = page_width
    assert_operator scroll, :<=, client, "the page is #{scroll}px wide in a #{client}px window with the media information #{state}"
  end

  test "a record page with a digital asset does not scroll sideways at 390px, with the media information closed, open or closed again" do
    visit search_catalog_path(f: { has_digital_asset: [ "with" ] }, q: "")
    first("#documents .document-title-heading a").click
    assert_selector ".digital-assets__stage"

    assert_no_sideways_scroll("closed")

    info = find("button.media-viewer__info-button")
    page.execute_script("arguments[0].scrollIntoView({ block: 'center' })", info) # clear of the sticky search strip
    info.click
    assert_selector "dialog#media-information[open]"
    assert_no_sideways_scroll("open")

    find("#media-information button[aria-label='Close media information']").click
    assert_no_selector "dialog#media-information[open]"
    assert_no_sideways_scroll("closed again")
  end
end
