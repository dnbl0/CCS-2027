# frozen_string_literal: true

# The header's Search collections menu: the collections, each with its number of records, and the number of records with
# images under them. Every collection link opens the whole set: the any_assets marker keeps the default "With a digital
# asset" filter off (docs/adr/0004). The collections and their order come from config/pages.yml (SitePages.menu).
#
# The numbers come from one Solr request, kept for a day. If Solr cannot answer, the menu is drawn without them (and
# asks again next time).
module BrowseMenu
  Group = Data.define(:id, :heading, :items)
  Item = Data.define(:label, :field, :value, :count)

  COLLECTION_FIELD = "collection_ssim"
  WITH_IMAGES = %w[has_digital_asset_bsi true].freeze
  CACHE_KEY = "browse_menu/counts/v2"

  # counts: { [field, value] => Integer }, as BrowseMenu.counts returns (empty when Solr is unavailable)
  def self.groups(counts = self.counts)
    collections = SitePages.menu.map { |label, value, _slug| item(label, COLLECTION_FIELD, value, counts) }
    [ Group.new("collections", "Museums and collections", collections) ]
  end

  # The query that opens every record with this value
  def self.query(field, value) = { any_assets: "1", f: { field => [ value ] }, search_field: "all_fields" }

  # connection: the Solr connection to ask (the tests pass their own)
  def self.counts(connection = nil)
    Rails.cache.fetch(CACHE_KEY, expires_in: 1.day, skip_nil: true) { fetch_counts(connection || Blacklight.default_index.connection) } || {}
  end

  def self.fetch_counts(connection)
    pairs = groups({}).flat_map(&:items).map { |entry| [ entry.field, entry.value ] } << WITH_IMAGES
    response = connection.get("select", params: {
      q: "*:*", rows: 0, facet: true, "facet.query": pairs.map { |field, value| facet_query(field, value) }, wt: "json"
    })
    found = response.dig("facet_counts", "facet_queries") || {}
    pairs.to_h { |field, value| [ [ field, value ], found[facet_query(field, value)] ] }
  rescue RSolr::Error::Http, RSolr::Error::ConnectionRefused, RSolr::Error::Timeout, Faraday::Error => e
    Rails.logger.warn("Browse menu counts unavailable: #{e.class}")
    nil
  end

  def self.facet_query(field, value) = %(#{field}:"#{value.gsub(/["\\]/) { |c| "\\#{c}" }}")

  def self.item(label, field, value, counts) = Item.new(label, field, value, counts[[ field, value ]])

  private_class_method :fetch_counts, :facet_query, :item
end
