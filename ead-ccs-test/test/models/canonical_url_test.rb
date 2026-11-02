require "test_helper"

class CanonicalUrlTest < ActiveSupport::TestCase
  BASE = "https://ccs.example.edu.au"

  test "a results page drops sort, view, per_page and tracking, and keeps what changes the results" do
    params = { "q" => "skull", "search_field" => "all_fields", "f" => { "collection_ssim" => [ "Medical History Museum" ] },
               "sort" => "title_si asc", "view" => "list", "per_page" => "96", "utm_source" => "x", "fbclid" => "y", "gclid" => "z" }

    url = CanonicalUrl.for(BASE, "/catalog", params)

    assert_equal "#{BASE}/catalog?#{{ 'f' => { 'collection_ssim' => [ 'Medical History Museum' ] }, 'q' => 'skull', 'search_field' => 'all_fields' }.to_query}", url
  end

  test "the same search in another order of parameters has one canonical" do
    one = CanonicalUrl.for(BASE, "/catalog", { "q" => "a", "search_field" => "title" })
    two = CanonicalUrl.for(BASE, "/catalog", { "search_field" => "title", "q" => "a", "view" => "list" })
    assert_equal one, two
  end

  test "page 1 has no page parameter; a later page keeps its own" do
    assert_equal "#{BASE}/catalog?q=a", CanonicalUrl.for(BASE, "/catalog", { "q" => "a", "page" => "1" })
    assert_equal "#{BASE}/catalog?page=3&q=a", CanonicalUrl.for(BASE, "/catalog", { "q" => "a", "page" => "3" })
  end

  test "blank parameters are dropped" do
    assert_equal "#{BASE}/catalog", CanonicalUrl.for(BASE, "/catalog", { "q" => "", "range" => {} })
  end

  test "all three record pages, and a record's citation, have the record page as canonical" do
    %w[/catalog/emu-9044 /stock/emu-9044 /branded-stock/emu-9044 /catalog/emu-9044/citation].each do |path|
      assert_equal "#{BASE}/catalog/emu-9044", CanonicalUrl.for(BASE, path, { "q" => "x", "utm_source" => "y" }), path
    end
  end

  test "other pages are their own path, without parameters, and the home page ends in a slash" do
    assert_equal "#{BASE}/help", CanonicalUrl.for(BASE, "/help", { "topic" => "x" })
    assert_equal "#{BASE}/", CanonicalUrl.for(BASE, "/", { "utm_medium" => "x" })
    assert_equal "#{BASE}/catalog/advanced", CanonicalUrl.for("#{BASE}/", "/catalog/advanced", { "x" => "y" })
  end
end
