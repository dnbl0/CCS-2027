require "test_helper"

class SitemapTest < ActiveSupport::TestCase
  BASE = "https://ccs.example.edu.au"

  def sitemap(records, page_size: 10_000) = Sitemap.new(base_url: BASE, records: -> { records }, page_size: page_size)

  test "the public pages come first, then each record" do
    urls = sitemap([ [ "emu-1", "2026-11-01" ] ]).urls.map(&:first)

    assert_equal "#{BASE}/", urls.first
    assert_includes urls, "#{BASE}/help"
    assert_includes urls, "#{BASE}/about"
    assert_includes urls, "#{BASE}/accessibility"
    assert_includes urls, "#{BASE}/privacy"
    assert_includes urls, "#{BASE}/catalog/advanced"
    assert_equal "#{BASE}/catalog/emu-1", urls.last
  end

  test "a record id is escaped in the address and in the XML" do
    xml = sitemap([ [ "a b&c", nil ] ]).page_xml(1)

    assert_includes xml, "<loc>#{BASE}/catalog/a%20b%26c</loc>"
    assert_nothing_raised { Nokogiri::XML(xml) { |config| config.strict } }
  end

  test "pages hold at most the page size, and the index lists every page" do
    records = (1..22).map { |n| [ "r#{n}", nil ] } # 8 public pages and 22 records: 30 URLs
    map = sitemap(records, page_size: 10)

    assert_equal 3, map.page_count
    assert_equal 10, Nokogiri::XML(map.page_xml(1)).css("url").size
    assert_equal 10, Nokogiri::XML(map.page_xml(3)).css("url").size
    assert_equal %w[1 2 3].map { |n| "#{BASE}/sitemaps/#{n}.xml" }, Nokogiri::XML(map.index_xml).css("sitemap loc").map(&:text)
    assert_nil map.page_xml(4)
    assert_nil map.page_xml(0)
  end

  test "the default page size is the protocol-safe 10,000" do
    assert_equal 10_000, Sitemap::PAGE_SIZE
    assert_equal 2, sitemap((1..10_000).map { |n| [ "r#{n}", nil ] }).page_count
  end

  test "no asset address is in any page" do
    assert_not_includes sitemap([ [ "emu-1", nil ] ]).page_xml(1), "digital-assets"
  end

  test "the record source walks Solr with a cursor and leaves out withheld and sensitive records" do
    connection = Class.new do
      attr_reader :calls

      def get(_path, params:)
        (@calls ||= []) << params[:cursorMark]
        if params[:cursorMark] == "*"
          { "nextCursorMark" => "c2", "response" => { "docs" => [
            { "id" => "open", "timestamp" => "2026-11-01T01:02:03Z", "licence_type_ssim" => [ "Public domain - Copyright expired" ] },
            { "id" => "icip", "licence_type_ssim" => [ "ICIP Rights" ] },
            { "id" => "community", "access_condition_ssi" => "Community Restricted" } ] } }
        else
          { "nextCursorMark" => "c2", "response" => { "docs" => [ { "id" => "sens", "restrictions_tsi" => [ "Culturally sensitive" ] }, { "id" => "plain" } ] } }
        end
      end
    end.new

    assert_equal [ [ "open", "2026-11-01" ], [ "plain", nil ] ], Sitemap::RecordSource.call(connection)
    assert_equal %w[* c2], connection.calls
  end
end
