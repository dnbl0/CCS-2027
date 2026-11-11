require "application_system_test_case"

# WCAG 1.4.10 Reflow: a record page with a digital asset fits a 390px phone without scrolling sideways. The closed Media metadata
# panel waits off the stage's right edge (transform + visibility, components/digital_assets.css); the stage must clip it rather than
# let it widen the page. Checked closed, open, and closed again.
class RecordMediaReflowTest < ApplicationSystemTestCase
  setup do
    page.driver.set_cookie("country_acknowledged", "1")
    page.current_window.resize_to(390, 844)
  end

  teardown { page.current_window.resize_to(1400, 900) }

  def page_width = page.evaluate_script("[document.documentElement.scrollWidth, document.documentElement.clientWidth]")

  def assert_no_sideways_scroll(state)
    scroll, client = page_width
    assert_operator scroll, :<=, client, "the page is #{scroll}px wide in a #{client}px window with the panel #{state}"
  end

  test "a record page with a digital asset does not scroll sideways at 390px, with the media panel closed, open or closed again" do
    visit search_catalog_path(f: { has_digital_asset: [ "with" ] }, q: "")
    first("#documents .document-title-heading a").click
    assert_selector ".digital-assets__stage"

    assert_no_sideways_scroll("closed")

    find("button[aria-controls=media-metadata]").click
    assert_selector ".digital-assets__panel.is-open", visible: :all
    assert_no_sideways_scroll("open")

    click_button "Close media information"
    assert_no_selector ".digital-assets__panel.is-open", visible: :all
    sleep 0.4 # let the slide-out transition finish
    assert_no_sideways_scroll("closed again")
  end
end
