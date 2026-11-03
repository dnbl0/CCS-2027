# frozen_string_literal: true

module Browse
  # The browse pages that go in the sitemap: the hubs, and each entity page with at least MIN_INDEXED_RECORDS records (a page
  # of fewer is thin, and asks not to be indexed, so listing it would contradict itself). At the time of writing that is about
  # 1,500 of some 9,000 values, so the sitemap grows by a fraction of one 10,000-URL page. The value lists come from the cache
  # (Index), so building the sitemap does not walk Solr again.
  module SitemapPaths
    HUB_PATHS = %w[/browse /browse/creators /browse/places /browse/subjects /browse/time].freeze

    def self.paths
      entities = Kind.all.flat_map { |kind| Index.for(kind).entries.select { |entry| entry.count >= MIN_INDEXED_RECORDS }.map(&:path) }
      periods = Periods.counts
      time = (periods.centuries + periods.decades).select { |_, count| count >= MIN_INDEXED_RECORDS }.map { |period, _| period.path }
      HUB_PATHS + entities.sort + time
    end
  end
end
