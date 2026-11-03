# frozen_string_literal: true

# Entity pages (see docs/browse-and-entities.md): one page for each maker, place and subject, and for each century and decade, linked from
# the browse index pages (BrowseHubs, BrowseList, BrowseController) and from the record page. Everything is derived from Solr facets that
# already exist (creator_ssim, production_place_ssim, subject_ssim, date_start_isi); nothing is stored.
#
#   Browse::Kind      which field a kind lists, and its labels
#   Browse::Index     every value of a kind with its record count, grouped by spelling variant, cached (over BrowseHubs.values)
#   Browse::Slug      the address of a value: readable words plus a short hash, so a value is found without a lookup table
#   Browse::Periods   centuries and decades of date_start_isi, the spans of BrowseHubs.periods
#   Browse::Profile   one Solr request for an entity page: the records and the facts about them
#   Browse::Meta      the description, robots and JSON-LD of an entity page (PageMeta draws it)
#   Browse::SitemapPaths  the browse pages that are listed in the sitemap
module Browse
  # How long the value lists and counts are kept. The index is rebuilt by the first visit after this; a Solr outage does not
  # empty it while the old copy is still there (the cache entry is only replaced by a successful build).
  CACHE_TTL = 6.hours

  # An entity page with fewer records than this is a thin page: it is reachable and works, but it asks search engines not to
  # index it and is left out of the sitemap (Browse::SitemapPaths).
  MIN_INDEXED_RECORDS = 5

  # Records shown on an entity page, and on a hub page (values)
  GRID_SIZE = 24
  HUB_PAGE_SIZE = 120

  # A value that says "nobody is known" is not an entity: "Unknown", "Unknown (posters)", "Anonymous". The records stay
  # searchable; they are simply not gathered under a page of their own.
  NOISE = /\A(unknown|anonymous|unidentified|not specified|n\/a)(\s*\(.*\))?\z/i

  def self.noise?(value) = value.to_s.strip.match?(NOISE) || value.to_s.strip.empty?

  # Years as a visitor reads them: negative years are BCE
  def self.year(value)
    value = value.to_i
    value.negative? ? "#{ActiveSupport::NumberHelper.number_to_delimited(-value)} BCE" : value.to_s
  end

  # The address of the page for a value as a record spells it, or nil when there is no such page (noise, an unknown kind). It needs
  # no Solr request: a value of an indexed record always has a page, and the slug is computed from the value (Browse::Slug).
  def self.path_for(kind_key, value)
    return if Browse.noise?(value) || Kind.find(kind_key).nil?

    Rails.application.routes.url_helpers.browse_entity_path(kind: kind_key, slug: Slug.build(kind_key, value.to_s.strip))
  end

  # The query-string search of the records with these facet values (any of them), as the catalog understands it. The
  # any_assets marker keeps the default "With a digital asset" filter off (docs/adr/0004): the page counted every record.
  def self.search_query(field, values)
    values = Array(values)
    filters = values.one? ? { f: { field => values } } : { f_inclusive: { field => values } }
    { any_assets: "1", search_field: "all_fields" }.merge(filters)
  end

  # A Solr phrase for a value taken from the index. Quotes and backslashes are escaped, so a value cannot end the phrase.
  def self.phrase(value) = %("#{value.to_s.gsub(/["\\]/) { |c| "\\#{c}" }}")

  def self.field_query(field, values) = "#{field}:(#{Array(values).map { |value| phrase(value) }.join(' OR ')})"
end
