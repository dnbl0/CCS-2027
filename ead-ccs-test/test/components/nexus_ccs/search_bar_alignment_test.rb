require "test_helper"

# The "All Fields" scope button in the search bar sat 2px taller than the input and the search button beside it and drew its own navy
# outline inside the bar's: the site's dropdown button is 3rem with its own border, the bar's inside is 3rem less its outline.
class SearchBarAlignmentTest < ActiveSupport::TestCase
  CSS = Rails.root.join("app/assets/stylesheets/components/search_banner.css").read

  test "the scope button fills the bar's inside like the input and search button, with no outline of its own" do
    rule = CSS[/> :is\(#sortAndPerPage \.btn-group, \.ccs-select\) > \.dropdown-toggle \{(.*?)\n\}/m, 1]

    assert rule, "the in-bar scope button rule (with the id in :is() so it outranks the site's dropdown rule)"
    assert_includes rule, "height: 100%;"
    assert_includes rule, "border: 0;"
    assert_match(/border-left: 1px solid var\(--ccs-border-default\);/, rule)
  end
end
