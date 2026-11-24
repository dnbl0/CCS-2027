require "test_helper"

# Every page's title follows one pattern (docs/ia-audit-handover.md): "Page — Collections Navigator — University of Melbourne", and the
# home page "Collections Navigator — University of Melbourne". The pages that answer without Solr are fetched; the search results and
# record pages' titles come from Blacklight's keys, checked as written.
class PageTitlesTest < ActionDispatch::IntegrationTest
  PATTERN = /\A.+ — Collections Navigator — University of Melbourne\z/

  test "the site's own pages share the pattern" do
    %w[/help /about /accessibility /privacy /language-in-our-records /themes /stories /lists].each do |path|
      get path
      title = css_select("title").first&.text.to_s.squish
      assert_match PATTERN, title, path
    end
  end

  test "the search results, a record and the advanced search name themselves in the same pattern" do
    assert_equal "Search results for print — Collections Navigator — University of Melbourne",
                 I18n.t("blacklight.search.page_title.title", constraints: "print", application_name: "Collections Navigator")
    assert_equal "A skull — Collections Navigator — University of Melbourne",
                 I18n.t("blacklight.search.show.title", document_title: "A skull", application_name: "Collections Navigator")
    assert_equal "Advanced search — Collections Navigator — University of Melbourne",
                 I18n.t("blacklight.advanced_search.page_title", application_name: "Collections Navigator")
  end
end
