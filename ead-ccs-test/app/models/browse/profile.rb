# frozen_string_literal: true

module Browse
  # What an entity page shows about a set of records (the records of a creator, place or subject, or of a period), from ONE
  # Solr request: a page of the records (those with images first), the facets for the main collections, object types and related
  # entities, the span of years, the centuries or decades, and how many records carry cultural protocols.
  #
  #   target   anything answering #fq (the Solr filter) and #search_query (the same records on the results page)
  class Profile
    Result = Data.define(:total, :documents, :held_back, :page, :pages, :first_year, :last_year, :facets, :periods, :cultural)

    FACET_FIELDS = %w[collection_ssim object_type_ssim creator_ssim production_place_ssim subject_ssim].freeze
    FACET_LIMIT = 14
    # The fields the result card, the save control and the access checks read; not the whole record (assets_json is large)
    FIELDS = %w[id title_tsim creator_ssim creator_display_ssim object_type_ssim collection_ssim thumbnail_path_ssi has_digital_asset_bsi
                licence_type_ssim access_condition_ssi restrictions_tsi date_start_isi production_date_ssim].freeze
    # Records the collection staff mark as culturally protected (AccessPolicy, Sensitivity and CulturalProtocolsNoticeComponent
    # read the same signs; this counts them in one facet query)
    CULTURAL_QUERY = '{!key=cultural}licence_type_ssim:"ICIP Rights" OR access_condition_ssi:"Community Restricted" OR restrictions_tsi:cultur*'

    # periods: :centuries (the entity's records by century), or a [first, last] span to split into decades
    def self.call(fq:, page: 1, periods: :centuries, repository: nil)
      new(repository || Blacklight.default_index).call(fq, page.to_i.clamp(1, 1000), periods)
    end

    def initialize(repository)
      @repository = repository
    end

    def call(fq, page, periods)
      response = @repository.search(params: params(fq, page, periods))
      shown, held = response.documents.partition { |document| !RobotsPolicy.withheld?(document) }
      total = response.dig("response", "numFound").to_i
      stats = response.dig("stats", "stats_fields", Periods::FIELD) || {}
      Result.new(total, shown, held.size, page, [ (total.to_f / GRID_SIZE).ceil, 1 ].max, stats["min"]&.to_i, stats["max"]&.to_i,
                 FACET_FIELDS.to_h { |field| [ field, Facets.pairs(response, field) ] }, period_counts(response, periods),
                 Facets.query_count(response, "cultural"))
    end

    private

    def params(fq, page, periods)
      base = { q: "*:*", defType: "lucene", qt: "select", fq: [ fq ], rows: GRID_SIZE, start: (page - 1) * GRID_SIZE, fl: FIELDS.join(","),
               sort: "has_digital_asset_bsi desc, title_si asc, id asc", facet: true, "facet.mincount": 1, "json.nl": "map",
               "facet.field": FACET_FIELDS, "facet.limit": FACET_LIMIT, "facet.query": CULTURAL_QUERY,
               stats: true, "stats.field": Periods::FIELD }
      base.merge(range_params(periods))
    end

    def range_params(periods)
      if periods == :centuries
        { "facet.range": Periods::FIELD, "facet.range.start": Periods::FIRST_CENTURY, "facet.range.end": Periods::LATEST_YEAR,
          "facet.range.gap": 100, "facet.range.other": "before" }
      elsif periods.respond_to?(:first) && periods.first
        { "facet.range": Periods::FIELD, "facet.range.start": periods.first, "facet.range.end": periods.last + 1, "facet.range.gap": 10 }
      else
        {}
      end
    end

    # [[Period, count], ...] in time order
    def period_counts(response, periods)
      return [] unless periods == :centuries || periods.respond_to?(:first) && periods.first

      gap = periods == :centuries ? 100 : 10
      counts = Facets.range(response, Periods::FIELD).map { |start, count| [ Periods.for_range_start(start, gap), count ] }.sort_by { |period, _| period.first }
      earlier = periods == :centuries ? Facets.before(response, Periods::FIELD) : 0
      earlier.positive? ? [ [ Periods.before, earlier ] ] + counts : counts
    end
  end
end
