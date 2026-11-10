require "application_system_test_case"

# Facet value lists and the facet "more" modal's list on a page of its own (/catalog/facet/<field>, which is what the modal loads), as
# components/facet_list.css lays them out. Computed styles in a real browser: what a person sees, not the stylesheet's text.
class FacetLayoutTest < ApplicationSystemTestCase
  setup { page.driver.set_cookie("country_acknowledged", "1") }

  def style(selector, property)
    page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json}))[#{property.to_json}]")
  end

  test "a facet label that wraps starts every line in the same place (no hanging indent) in the filter sidebar" do
    visit search_catalog_path(any_assets: "1", q: "")
    assert_selector "#sidebar .facet-label", visible: :all
    assert_equal "0px", style("#sidebar .facet-label", "textIndent")
    assert_equal "0px", style("#sidebar .facet-label", "paddingLeft")
    # the gap before the count stays
    assert_not_equal "0px", style("#sidebar .facet-label", "paddingRight")
  end

  test "the A-Z facet page: the letter bar is spaced from the filter box, an even grid, and a letter with no values says so" do
    visit "/catalog/facet/creator_role_ssim?facet.sort=index"
    assert_selector ".alpha-filter .page-link", minimum: 27
    assert_equal "0px", style(".facet-extended-list .facet-label", "textIndent")
    assert_equal "16px", style(".alpha-filter", "marginTop")
    assert_equal "grid", style(".alpha-filter .pagination", "display")
    assert_operator style(".alpha-filter .page-link", "minWidth").to_f, :>=, 36
    assert_accessible

    # a letter with no values: the list has no labels in it (emptied here, so the test does not depend on what the index holds)
    page.execute_script("document.querySelector('.facet-extended-list').innerHTML = ''")
    assert_equal "Nothing to show here.", page.evaluate_script("getComputedStyle(document.querySelector('.facet-extended-list'), '::before').content").delete('"')
    assert_accessible
  end

  test "the facet modal: a smaller heading, and the letter bar fits inside it" do
    visit search_catalog_path(any_assets: "1", q: "")
    page.execute_script("document.querySelector('#sidebar a[data-blacklight-modal=trigger]').click()")
    assert_selector "#blacklight-modal .modal-title"
    assert_equal "24px", style("#blacklight-modal .modal-title", "fontSize") # the panel heading size (--ccs-heading-panel-size)
    first("#blacklight-modal a.sort_change.az").click
    assert_selector "#blacklight-modal .alpha-filter .page-link", minimum: 27
    assert page.evaluate_script(<<~JS), "the letter bar is wider than the modal"
      (function () { var bar = document.querySelector('#blacklight-modal .alpha-filter').getBoundingClientRect(), body = document.querySelector('#blacklight-modal .modal-body').getBoundingClientRect(); return bar.right <= body.right + 1 && bar.left >= body.left - 1 })()
    JS
    assert_accessible
  end
end
