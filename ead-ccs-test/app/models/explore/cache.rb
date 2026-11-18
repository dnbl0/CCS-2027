# frozen_string_literal: true

module Explore
  # The explore pages' answers, kept for a few hours and the last good copy for a month (as BrowseHubs), so Solr going down
  # still leaves a page to show. nil when Solr cannot answer and nothing is kept.
  module Cache
    def self.fetch(key, expires_in: 6.hours)
      Rails.cache.fetch(SuppressedRecord.cache_key("explore/v1/#{key}"), expires_in: expires_in, skip_nil: true) do
        fresh = guarded(key) { yield }
        Rails.cache.write(SuppressedRecord.cache_key("explore/last_good/v1/#{key}"), fresh, expires_in: 30.days) if fresh
        fresh
      end || Rails.cache.read(SuppressedRecord.cache_key("explore/last_good/v1/#{key}"))
    end

    def self.guarded(key)
      yield
    rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable => e
      Rails.logger.warn("Explore #{key} unavailable: #{e.class}")
      nil
    end

    def self.get(connection, params) = SolrGuard.run { (connection || Blacklight.default_index.connection).get("select", params: params) }
  end
end
