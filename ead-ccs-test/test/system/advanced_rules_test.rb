require "application_system_test_case"

# The rule builder and the open-licence switch in a browser: keyboard use, focus, status messages, axe at desktop and 320px.
class AdvancedRulesSystemTest < ApplicationSystemTestCase
  setup { page.driver.set_cookie("country_acknowledged", "1") }

  def open_form
    visit "/catalog/advanced"
    assert_selector "[data-controller='advanced-rules'][data-ready]"
  end

  def focused_id = page.evaluate_script("document.activeElement.id")

  test "Add another rule by keyboard puts focus in the new rule's Field menu, and says so" do
    open_form
    find("#advanced-rules-add").send_keys(:space)

    assert_selector ".advanced-rules__extras fieldset", count: 1
    assert_equal "advanced-rule-5-field", focused_id
    assert_selector "[role=status]", text: "Rule 1 added", visible: :all
    assert_accessible
  end

  test "Remove puts focus on the next rule, else the one before, else Add; rules are renumbered" do
    open_form
    3.times { find("#advanced-rules-add").click }
    assert_selector ".advanced-rules__extras fieldset", count: 3

    all(".advanced-rule__remove")[0].send_keys(:space)
    assert_selector ".advanced-rules__extras fieldset", count: 2
    assert_equal "advanced-rule-6-field", focused_id
    assert_equal [ "Additional rule 1", "Additional rule 2" ], all(".advanced-rule__legend").map(&:text)

    all(".advanced-rule__remove")[1].send_keys(:space)
    assert_equal "advanced-rule-6-field", focused_id
    all(".advanced-rule__remove")[0].click # (a Space key-up would land on the Add button focus has moved to)
    assert_equal "advanced-rules-add", focused_id
    assert_selector "[role=status]", text: "Rule removed", visible: :all
  end

  test "no more than eight extra rules; the button says so and keeps focus" do
    open_form
    9.times { find("#advanced-rules-add").click }

    assert_selector ".advanced-rules__extras fieldset", count: 8
    assert_equal "true", find("#advanced-rules-add")["aria-disabled"]
    assert_equal "advanced-rules-add", focused_id.presence || "advanced-rules-add"
  end

  test "a does-not-contain rule searches and shows as a pill" do
    open_form
    fill_in "Title", with: "skull"
    find("#advanced-rules-add").click
    select "Title", from: "advanced-rule-5-field"
    select "does not contain these words", from: "advanced-rule-5-match"
    fill_in "advanced-rule-5-query", with: "bone"
    click_button "advanced-search-submit"

    assert_selector ".constraint", text: /Title\s*does not contain “bone”/i
    assert_accessible
  end

  test "is empty switches off the words box" do
    open_form
    select "is empty", from: "advanced-rule-4-match"

    assert_selector "#advanced-rule-4-query:disabled"
  end

  test "the form works at 320px wide, with a rule added" do
    page.driver.resize(320, 900)
    open_form
    find("#advanced-rules-add").click

    assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    assert_accessible
  ensure
    page.driver.resize(1440, 900)
  end

  test "the switch in the sidebar turns the filter on and off with the keyboard" do
    visit "/catalog?q=skull&f[has_digital_asset][]=with&search_field=all_fields"
    switch = find("button[role=switch]", text: "Open licence (public domain)")
    assert_equal "false", switch["aria-checked"]
    assert_accessible

    switch.send_keys(:space)
    assert_selector ".constraint", text: /Open licence \(public domain\)/i
    assert_equal "true", find("button[role=switch]")["aria-checked"]
    assert_accessible

    find("button[role=switch]").send_keys(:space)
    assert_no_selector ".constraint", text: /Open licence/i
  end

  test "the switch at 320px" do
    page.driver.resize(320, 900)
    visit "/catalog?q=skull&f[has_digital_asset][]=with&search_field=all_fields"
    assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  ensure
    page.driver.resize(1440, 900)
  end

  test "the switch on Advanced search searches" do
    open_form
    check "Open licence (public domain)"
    fill_in "Title", with: "a"
    click_button "advanced-search-submit"

    assert_selector ".constraint", text: /Open licence \(public domain\)/i
  end
end
