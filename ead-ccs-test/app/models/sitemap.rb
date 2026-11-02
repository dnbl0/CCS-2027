# frozen_string_literal: true

require "cgi"

# /sitemap.xml and its child sitemaps (CCS-128): a sitemap index, then pages of at most 10,000 URLs each (the protocol allows 50,000;
# 10,000 keeps each response small). The public pages come first, then the record pages in id order. A record whose title and
# description stay out of search results (RobotsPolicy.withheld?) is left out, and no asset address appears: only /catalog/:id.
#
# The records come from Solr, read-only, with a cursor (RecordSource); the list of ids is cached (SEO_SITEMAP_CACHE_HOURS),
# so a request does not walk the index. `records` is anything answering #call with [[id, lastmod], ...]; tests hand one in.
class Sitemap
  PAGE_SIZE = 10_000
  XMLNS = "http://www.sitemaps.org/schemas/sitemap/0.9"
  # The results page is the default search, as /catalog redirects to it (SearchDefaults), so the redirect is not what is listed
  STATIC_PATHS = %w[/ /catalog?f%5Bhas_digital_asset%5D%5B%5D=with&search_field=all_fields /catalog/advanced /help /about /accessibility /privacy].freeze

  def initialize(base_url:, records:, page_size: PAGE_SIZE)
    @base_url = base_url.to_s.chomp("/")
    @records = records
    @page_size = page_size
  end

  def page_count = [ (urls.size.to_f / @page_size).ceil, 1 ].max

  def index_xml(lastmod: nil)
    entries = (1..page_count).map { |page| "<sitemap><loc>#{escape("#{@base_url}/sitemaps/#{page}.xml")}</loc>#{lastmod_tag(lastmod)}</sitemap>" }
    document("sitemapindex", entries)
  end

  # nil for a page that does not exist
  def page_xml(page)
    return nil unless page.between?(1, page_count)

    entries = urls.slice((page - 1) * @page_size, @page_size).map do |loc, lastmod|
      "<url><loc>#{escape(loc)}</loc>#{lastmod_tag(lastmod)}</url>"
    end
    document("urlset", entries)
  end

  # Every URL: [address, lastmod or nil]
  def urls
    @urls ||= STATIC_PATHS.map { |path| [ path == "/" ? "#{@base_url}/" : "#{@base_url}#{path}", nil ] } +
              @records.call.map { |id, lastmod| [ "#{@base_url}/catalog/#{ERB::Util.url_encode(id)}", lastmod ] }
  end

  private

  def document(root, entries)
    %(<?xml version="1.0" encoding="UTF-8"?>\n<#{root} xmlns="#{XMLNS}">\n#{entries.join("\n")}\n</#{root}>\n)
  end

  def lastmod_tag(lastmod) = lastmod ? "<lastmod>#{escape(lastmod)}</lastmod>" : ""
  def escape(text) = CGI.escapeHTML(text.to_s)

  # The records in Solr that may be listed, as [id, date of last change] in id order
  module RecordSource
    FIELDS = %w[id timestamp licence_type_ssim access_condition_ssi restrictions_tsi].freeze
    ROWS = 1000

    def self.call(connection = Blacklight.default_index.connection)
      cursor = "*"
      listed = []
      loop do
        response = connection.get("select", params: { q: "*:*", sort: "id asc", rows: ROWS, cursorMark: cursor, fl: FIELDS.join(","), wt: "json" })
        response["response"]["docs"].each do |doc|
          document = SolrDocument.new(doc)
          listed << [ doc["id"], doc["timestamp"]&.slice(0, 10) ] unless RobotsPolicy.withheld?(document)
        end
        break if response["nextCursorMark"].nil? || response["nextCursorMark"] == cursor

        cursor = response["nextCursorMark"]
      end
      listed
    end

    # The cached list (Rails.cache: see docs/seo-and-bot-controls.md for what that is in each environment)
    def self.cached
      Rails.cache.fetch("sitemap/records/v1", expires_in: BotControls.sitemap_cache_hours.hours, race_condition_ttl: 30.seconds) { call }
    end
  end
end
