# frozen_string_literal: true

# Every University cultural collection (config/university_collections.yml: the list on museumsandcollections.unimelb.edu.au/collections),
# split into the ones that can be searched here and the ones that are not yet, which link to their own site. The home page's
# "All University collections" lists both.
#
# A collection is searchable here when it has a landing page (config/pages.yml) OR the index holds records whose collection_ssim is its
# name (or its `facet_value` in the YAML, when the index spells it differently). So when a collection's records are loaded, it moves to
# "search here" by itself within an hour (the counts are cached), with no code change. Its search is the collection_ssim filter, the
# same one the facet and the header menu use, and a search from its results stays inside it (the search form carries the filter).
module UniversityCollections
  COLLECTION_FIELD = "collection_ssim"
  CACHE_KEY = "university_collections/counts"
  COUNTS_TTL = 1.hour
  OUTAGE_TTL = 1.minute

  Entry = Data.define(:name, :url, :slug, :facet_value, :records) do
    # The search that opens the collection's records: the collection filter, as the header menu and the facet use it
    def search_params = BrowseMenu.query(COLLECTION_FIELD, facet_value)
  end

  # counts: { collection_ssim value => records }; defaults to the (cached) index counts. Tests pass their own.
  def self.all(counts = self.counts)
    configured.map do |row|
      value = row["facet_value"] || row.fetch("name")
      Entry.new(name: row.fetch("name"), url: row.fetch("url"), slug: NexusCcs::SiteNavigation.slug_for(value), facet_value: value,
                records: counts.fetch(value, 0))
    end
  end

  def self.in_collections_navigator(counts = self.counts) = all(counts).select { |entry| entry.slug || entry.records.positive? }

  def self.elsewhere(counts = self.counts) = all(counts).reject { |entry| entry.slug || entry.records.positive? }

  # { value => records } for every collection in the index, kept for an hour. When Solr is unavailable the answer is {} (then only the
  # landing-page collections are searchable), kept for a minute so a struggling Solr is not asked again by every page view.
  def self.counts
    key = SuppressedRecord.cache_key(CACHE_KEY)
    Rails.cache.read(key) || begin
      fetched = fetch_counts
      Rails.cache.write(key, fetched || {}, expires_in: fetched ? COUNTS_TTL : OUTAGE_TTL)
      fetched || {}
    end
  end

  def self.fetch_counts
    response = SolrGuard.run do
      Blacklight.default_index.connection.get("select", params: {
        q: "*:*", rows: 0, wt: "json", facet: true, "facet.field": COLLECTION_FIELD, "facet.mincount": 1, "facet.limit": -1
      })
    end
    response.dig("facet_counts", "facet_fields", COLLECTION_FIELD).to_a.each_slice(2).to_h { |value, count| [ value, count.to_i ] }
  rescue *SolrGuard::FAILURES, SolrGuard::Unavailable
    nil
  end
  private_class_method :fetch_counts

  def self.configured = @configured ||= YAML.load_file(Rails.root.join("config/university_collections.yml")).freeze
  private_class_method :configured
end
