# frozen_string_literal: true

# The most viewed records of the last few days (RecordView), for the home page and /discover (docs/similar-and-trending.md).
# Counts are aggregate and anonymous; this only reads them. When the data is thin (fewer than MINIMUM records have enough views
# in the window, or Trending is off, or the database or Solr fail) the answer is [] and the page shows Featured alone.
class TrendingRecords
  MINIMUM = 3
  CACHE_MINUTES = 10

  # Up to `limit` SolrDocuments, most viewed first, or []. A record counted when it was open to view but withheld or made
  # sensitive since is checked again here (Discovery.listable?) and dropped.
  def self.documents(limit: 12)
    return [] unless RecordView.enabled?

    ids = Rails.cache.fetch("discover/trending/v1/#{RecordView.window_days}/#{limit}", expires_in: CACHE_MINUTES.minutes) do
      RecordView.top(limit: limit * 2).map(&:first)
    end
    return [] if ids.size < MINIMUM

    found = Discovery.fetch(ids).select { |document| Discovery.listable?(document) }.first(limit)
    found.size >= MINIMUM ? found : []
  rescue StandardError => error
    Discovery.log_failure("Trending records", error)
    []
  end
end
