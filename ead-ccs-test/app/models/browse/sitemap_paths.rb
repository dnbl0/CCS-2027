# frozen_string_literal: true

module Browse
  # The browse pages that go in the sitemap: the browse index pages, and each entity page with at least MIN_INDEXED_RECORDS records (a
  # page of fewer is thin, and asks not to be indexed, so listing it would contradict itself). Today that is about 1,500 of some 9,000
  # values, so the sitemap grows by a fraction of one 10,000-URL page. The value lists come from the caches (Index, BrowseHubs), so
  # building the sitemap adds no Solr walk. A period is listed when it is in the periods list with that many records, and so is the
  # century of any listed decade.
  module SitemapPaths
    # Every Browse page at its own address (time, places and colours keep theirs); DiscoverySitemap lists the same few, so they are made one
    # (worked out when asked, not when the class loads: the routes may not be drawn yet)
    def self.hub_paths = [ "/browse" ] + BrowseHubs.all.map(&:path)

    def self.paths
      entities = Kind.all.flat_map { |kind| Index.for(kind).entries.select { |entry| entry.count >= MIN_INDEXED_RECORDS }.map(&:path) }
      listed = (BrowseHubs.period_entries || []).select { |_, count, _, _| count >= MIN_INDEXED_RECORDS }
      periods = listed.filter_map { |_, _, first, last| Periods.for_span(first, last) }
      periods += periods.filter_map(&:parent).uniq
      hub_paths + entities.sort + periods.uniq.map(&:path).sort
    rescue Index::Unavailable
      hub_paths
    end
  end
end
