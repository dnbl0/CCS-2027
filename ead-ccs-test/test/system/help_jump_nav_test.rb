require "application_system_test_case"

class HelpJumpNavTest < ApplicationSystemTestCase
  # A page opened at an address with a #section lands on that section at once: an animated first jump can be cut short
  # (a slow load, a background tab) and leave the page at the top. Smooth scrolling comes on only after the load
  # (app/javascript/smooth_scroll.js), so jumps within the page still scroll smoothly.
  test "a page opened at a #section lands on it, and smooth scrolling comes on only after the load" do
    page.driver.set_cookie("country_acknowledged", "1")
    visit "/help#contact-us"

    assert_operator evaluate_script("window.scrollY"), :>, 0
    assert_operator evaluate_script("Math.abs(document.getElementById('contact-us').getBoundingClientRect().top)"), :<, 200
    assert_selector "html.smooth-scroll", visible: :all
    assert_equal "smooth", evaluate_script("getComputedStyle(document.documentElement).scrollBehavior")
    # Before the class is added (the moment the browser makes the first jump) nothing turns smooth scrolling on, Bootstrap included
    assert_equal "auto", evaluate_script("document.documentElement.classList.remove('smooth-scroll'), getComputedStyle(document.documentElement).scrollBehavior")
  end

  test "the jump navigation marks the section being read as the reader scrolls" do
    visit help_path
    assert_selector "a.jump-nav__link[aria-current=location]", text: "Frequently Asked Questions"

    page.execute_script("document.getElementById('copyright').scrollIntoView()")
    assert_selector "a.jump-nav__link.is-current[aria-current=location]", text: "Copyright and Terms of Use"
    assert_selector "a.jump-nav__link[aria-current=location]", count: 1

    page.execute_script("window.scrollTo(0, document.documentElement.scrollHeight)")
    assert_selector "a.jump-nav__link.is-current", text: "Contact Us"
  end
end
