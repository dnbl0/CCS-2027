require "test_helper"
require_relative "../support/env_override"

class RobotsPolicyTest < ActiveSupport::TestCase
  include EnvOverride

  def directive(path, params = {}, **options) = RobotsPolicy.directive(path, params, indexing: true, **options)

  PERSONAL_PATHS = %w[
    /bookmarks /bookmarks/citations /bookmarks/clear /saved_searches /search_history /search_history/12 /lists /lists/3 /lists/3/citations
    /lists/3/items /galleries/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa /galleries/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/citations /embed/records/emu-9044 /embed/galleries/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa /oembed /compare /compare/items /compare/items/emu-9044 /catalog/emu-9044/manifest.json /access_requests/new /access_requests/9 /downloads /downloads/review /catalog/emu-9044/metadata
    /catalog/emu-9044/sensitivity /catalog/emu-9044/citation /stock/emu-9044/citation /404 /500
  ].freeze

  test "every personal or action page is noindex, nofollow" do
    PERSONAL_PATHS.each { |path| assert_match(/\Anoindex, nofollow/, directive(path), path) }
  end

  test "the facet, range and suggest endpoints are noindex, nofollow, and the stock comparison pages too" do
    %w[/catalog/facet/collection_ssim /catalog/range_limit /catalog/suggest /catalog/opensearch.xml /stock/emu-9044 /branded-stock/emu-9044].each do |path|
      assert_match(/\Anoindex, nofollow/, directive(path), path)
    end
  end

  test "the public pages are indexed (only the AI tags)" do
    %w[/ /help /about /catalog/advanced /catalog/emu-9044].each { |path| assert_equal "noai, noimageai", directive(path), path }
  end

  test "the results of the whole site and of one collection, page 1, are indexed" do
    assert_equal "noai, noimageai", directive("/catalog", { "f" => { "has_digital_asset" => [ "with" ] }, "search_field" => "all_fields", "sort" => "x", "view" => "list" })
    assert_equal "noai, noimageai", directive("/catalog", { "f" => { "collection_ssim" => [ "Grainger Museum" ] }, "any_assets" => "1" })
  end

  test "a search, another filter, a second page or an advanced search is noindex, follow" do
    [ { "q" => "skull" }, { "f" => { "creator_ssim" => [ "x" ] } }, { "f" => { "has_digital_asset" => [ "without" ] } },
      { "f" => { "collection_ssim" => [ "a", "b" ] } }, { "page" => "2" }, { "range" => { "date" => { "begin" => "1900" } } },
      { "clause" => { "0" => { "field" => "title", "query" => "x" } } } ].each do |params|
      assert_equal "noindex, follow, noai, noimageai", directive("/catalog", params), params.inspect
    end
  end

  test "a record whose asset is withheld, or that is sensitive, is noindex, follow" do
    withheld = SolrDocument.new("id" => "a", "licence_type_ssim" => [ "ICIP Rights" ])
    sensitive = SolrDocument.new("id" => "b", "restrictions_tsi" => [ "Culturally sensitive images" ])
    open = SolrDocument.new("id" => "c", "licence_type_ssim" => [ "Public domain - Copyright expired" ])
    assert_match(/\Anoindex, follow/, directive("/catalog/a", document: withheld))
    assert_match(/\Anoindex, follow/, directive("/catalog/b", document: sensitive))
    assert_equal "noai, noimageai", directive("/catalog/c", document: open)
  end

  test "the asset files are noindex" do
    assert_equal "noindex, noai, noimageai", directive("/digital-assets/large/a.jpg")
  end

  test "the site's own scripts, styles and the health check get no header" do
    %w[/assets/application.css /up /icon.png].each { |path| assert_nil directive(path), path }
  end

  test "with indexing off every page is noindex, nofollow" do
    assert_match(/\Anoindex, nofollow/, RobotsPolicy.directive("/", {}, indexing: false))
  end

  test "the AI tags go when BOT_CONTROLS is off" do
    with_env("BOT_CONTROLS" => "off") do
      assert_equal "", directive("/")
      assert_equal "noindex, nofollow", directive("/bookmarks")
    end
  end
end
