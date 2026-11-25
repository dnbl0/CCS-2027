# frozen_string_literal: true

# The browse pages behind the home page's Explore tiles (/browse): every object type, place, maker and subject, and every
# period, each opening all its records (the any_assets marker keeps the default "With a digital asset" filter off, docs/adr/0004).
#
# A list is one Solr request for all the values and their counts, kept for a day, and the last good list for a month, as
# BrowseMenu does (CCS-147). If Solr cannot answer and nothing is kept, there is no list (nil) and the page says so.
#
# Every page under /browse is one of these and has the one template (browse/hub, after Google Arts & Culture's category pages, looked at
# 2026-11-25): the title, the views as tabs (All: a mosaic of pictures; A–Z, or In order for time), and for time, places and colours a
# third tab, their explorer (the timeline, the map, the spectrum), drawn inside the same template (browse/_template).
module BrowseHubs
  Hub = Data.define(:slug, :title, :singular, :field, :intro) do
    # Its address: time, places and colours keep theirs (/browse/time, /browse/places, /browse/colours); the rest are /browse/<slug>
    def path(**params)
      routes = Rails.application.routes.url_helpers
      params = params.compact_blank
      case slug
      when "periods" then routes.explore_time_path(params)
      when "places" then routes.explore_places_path(params)
      when "colours" then routes.explore_colours_path(params)
      else routes.browse_hub_path(slug, params)
      end
    end

    # The third tab, its explorer: [the view's name in the address, its label key], or nil
    def explorer = EXPLORERS[slug]

    def periods? = slug == "periods"
  end
  EXPLORERS = { "periods" => "timeline", "places" => "map", "colours" => "spectrum" }.freeze
  UNKNOWN_MAKER = "Unknown"
  OTHER_LETTER = "#"
  MOST_RECORDS = 100 # the list shown before a letter is chosen
  FIRST_DECADE = 1800
  FIRST_CENTURY = 1000

  HUBS = [
    Hub.new("object-types", "Object types", "object type", ExploreEntryPoints::OBJECT_TYPE_FIELD, "What the records are: instruments, photographs, specimens and more."),
    Hub.new("places", "Places", "place", ExploreEntryPoints::PLACE_FIELD, "Where the objects were made or found."),
    Hub.new("periods", "Time", "period", ExploreEntryPoints::DATE_FIELD, "When the objects were made, by century and, from 1800, by decade."),
    Hub.new("makers", "Makers", "maker", "creator_ssim", "The people and organisations that made the objects."),
    Hub.new("subjects", "Subjects", "subject", "subject_ssim", "What the objects are about."),
    Hub.new("classifications", "Classifications", "classification", ExploreEntryPoints::CLASSIFICATION_FIELD,
            "The kinds of records the collections use to group them: prints, paintings, documents and more."),
    Hub.new("materials", "Materials", "material", "material_ssim", "What the objects are made of."),
    Hub.new("collections", "Collections", "collection", "collection_ssim", "The University's collections whose records are in Collections Navigator."),
    Hub.new("named-collections", "Named collections", "named collection", "named_collection_ssim", "Groups of records within a collection, often a gift or a bequest."),
    Hub.new("colours", "Colours", "colour", CatalogConfig::Facets::COLOUR_FIELD, "The colours of the records' images. Each opens the records with a lot of it.")
  ].freeze

  def self.all = HUBS

  def self.find(slug) = HUBS.find { |hub| hub.slug == slug.to_s }

  # A value's own page, or nil (it opens the search): a maker's, place's or subject's page, a collection's, or a colour's spectrum
  def self.value_path(hub, value)
    return if Browse.noise?(value)

    routes = Rails.application.routes.url_helpers
    case hub.slug
    when "makers", "places", "subjects" then Browse.path_for(hub.slug, value)
    when "collections", "named-collections" then routes.collection_landing_path(kind: hub.slug, slug: Browse::Slug.build(hub.slug, value.to_s))
    when "colours" then routes.explore_colours_path(colour: value)
    end
  end

  # The search that opens every record with this value
  def self.query(field, value) = { any_assets: "1", f: { field => [ value ] }, search_field: "all_fields" }

  def self.period_query(first, last)
    { any_assets: "1", range: { ExploreEntryPoints::DATE_FIELD => { begin: first, end: last } }, search_field: "all_fields" }
  end

  # [[value, count], ...], most records first; nil when Solr cannot answer and nothing is kept
  def self.values(hub, connection = nil)
    cached(hub.slug) do
      pairs = facet_pairs(hub, connection)
      pairs&.reject { |value, _count| hub.field == "creator_ssim" && value == UNKNOWN_MAKER }&.sort_by { |value, count| [ -count, value.to_s ] }
    end
  end

  # [[label, count, first year, last year], ...] in order of time, leaving out the empty ones; nil as for .values
  def self.period_entries(connection = nil, this_year = Time.zone.today.year)
    cached("periods") { period_values(connection, this_year) }
  end

  # [label, first year, last year]: before 1000, then by century to 1800, then by decade
  def self.periods(this_year = Time.zone.today.year)
    centuries = (FIRST_CENTURY...FIRST_DECADE).step(100).map { |year| [ "#{year}–#{year + 99}", year, year + 99 ] }
    decades = (FIRST_DECADE..this_year).step(10).map { |year| [ "#{year}–#{year + 9}", year, year + 9 ] }
    [ [ "Before 1000", ExploreEntryPoints::EARLIEST_YEAR, FIRST_CENTURY - 1 ], *centuries, *decades ]
  end

  def self.period_values(connection, this_year = Time.zone.today.year)
    list = periods(this_year)
    response = SolrGuard.run do
      (connection || Blacklight.default_index.connection).get("select", params: {
        q: "*:*", rows: 0, wt: "json", facet: true, "facet.query": list.map { |_label, first, last| ExploreEntryPoints.period_query(first, last) }
      })
    end
    found = response.dig("facet_counts", "facet_queries") || {}
    list.filter_map do |label, first, last|
      count = found[ExploreEntryPoints.period_query(first, last)].to_i
      [ label, count, first, last ] if count.positive?
    end
  rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable => e
    Rails.logger.warn("Browse periods unavailable: #{e.class}")
    nil
  end

  # The letters the values start with, in order; # (last) for names that start with a digit or a sign
  def self.letters(values) = values.map { |value, _count| letter_of(value) }.uniq.sort_by { |letter| letter == OTHER_LETTER ? "~" : letter }

  # The values under one letter, alphabetically
  def self.for_letter(values, letter)
    values.select { |value, _count| letter_of(value) == letter }.sort_by { |value, _count| I18n.transliterate(value.to_s).downcase }
  end

  def self.letter_of(value)
    first = I18n.transliterate(value.to_s).strip[0].to_s.upcase
    first.match?(/\A[A-Z]\z/) ? first : OTHER_LETTER
  end

  def self.cached(slug)
    Rails.cache.fetch(SuppressedRecord.cache_key("browse_hubs/v1/#{slug}"), expires_in: 1.day, skip_nil: true) do
      fetched = yield
      Rails.cache.write(SuppressedRecord.cache_key("browse_hubs/last_good/v1/#{slug}"), fetched, expires_in: 30.days) if fetched
      fetched
    end || Rails.cache.read(SuppressedRecord.cache_key("browse_hubs/last_good/v1/#{slug}"))
  end

  def self.facet_pairs(hub, connection)
    response = SolrGuard.run do
      (connection || Blacklight.default_index.connection).get("select", params: {
        q: "*:*", rows: 0, wt: "json", facet: true, "facet.field": hub.field, "facet.limit": -1, "facet.mincount": 1, "facet.sort": "count"
      })
    end
    response.dig("facet_counts", "facet_fields", hub.field).to_a.each_slice(2).to_a
  rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable => e
    Rails.logger.warn("Browse list unavailable: #{e.class}")
    nil
  end

  private_class_method :cached, :facet_pairs, :letter_of
end
