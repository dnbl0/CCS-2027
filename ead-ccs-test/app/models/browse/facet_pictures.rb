# frozen_string_literal: true

module Browse
  # A picture for each value in an entity page's "ways in" (its kinds of record, periods, places, makers and subjects), so those sections
  # can be the same picture mosaic as the rest of the page instead of lists of chips. ONE Solr request for the entity's records that have
  # a picture that may be shown (Browse::Cards::THUMBNAIL_FILTERS: a thumbnail, not sensitive, not restricted; AccessPolicy.view? checked
  # here too), kept for a day; each value then takes the first of those records that carries it, and no picture is used twice on the page.
  # A value none of them carries, or whose records here the page already shows (France has 22 pictured records for its ten kinds of
  # record), takes a picture of its own records anywhere in the collections (#prepare: one grouped request for the page's values, kept for
  # a day): a picture of London for "England, London".
  # Only a value with no picture anywhere has none (its tile then shows its number of records in the picture's place).
  class FacetPictures
    ROWS = 400
    ELSEWHERE = 12 # pictures kept for each value from the whole collection (enough to pass over the ones the page already shows)
    # the fields whose values the sections show (an entity page's, and a collection or theme page's eras and named collections)
    # (and Explore by colour's colours: their names are ranked, the biggest share of the image first)
    VALUE_FIELDS = %w[object_type_ssim creator_ssim production_place_ssim subject_ssim date_era_ssim named_collection_ssim colour_ssim].freeze
    FIELDS = (Profile::FIELDS + VALUE_FIELDS).uniq.freeze
    Picture = Data.define(:id, :src)

    # avoid: ids of records the page already shows (its Discover mosaic): taken only when nothing else carries the value
    def self.for(fq, avoid: [], repository: nil)
      documents = Rails.cache.fetch(SuppressedRecord.cache_key("facet_pictures/v1/#{Digest::SHA1.hexdigest(fq.to_s)}"), expires_in: 1.day, skip_nil: true) do
        fetch(fq, repository || Blacklight.default_index)
      end
      new(documents || [], avoid)
    end

    # [{ "id", "src", field => values, "year" }], or nil when Solr cannot answer
    def self.fetch(fq, repository)
      response = repository.search(params: { q: "*:*", defType: "lucene", qt: "select", fq: Array(fq) + Cards::THUMBNAIL_FILTERS, rows: ROWS,
                                             sort: "id asc", fl: FIELDS.join(","), facet: false })
      response.documents.filter_map do |document|
        next unless AccessPolicy.view?(document) && !Sensitivity.sensitive?(document)

        { "id" => document.id.to_s, "src" => document["thumbnail_path_ssi"].to_s, "year" => document["date_start_isi"],
          **VALUE_FIELDS.to_h { |field| [ field, Array(document[field]) ] } }
      end
    rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable => e
      Rails.logger.warn("Facet pictures unavailable: #{e.class}")
      nil
    end

    def initialize(documents, avoid = [], repository: nil)
      @documents = documents
      @avoid = avoid.to_set(&:to_s)
      @used = Set.new
      @elsewhere = {}
      @repository = repository
    end

    # Before the tiles: every value the page will show, as [field, spellings] or a period, looked for in the whole collection too with ONE
    # request, so a value whose own records here are all shown already (in Discover, or by an earlier tile) still has a picture of its own
    def prepare(wants)
      missing = wants.uniq.to_h { |want| [ query(want), want ] }
      return self if missing.empty?

      key = SuppressedRecord.cache_key("facet_pictures/elsewhere/v3/#{Digest::SHA1.hexdigest(missing.keys.sort.join("\n"))}")
      found = Rails.cache.fetch(key, expires_in: 1.day, skip_nil: true) { elsewhere(missing.keys) } || {}
      found.each { |solr_query, pictures| @elsewhere[missing[solr_query]] = pictures }
      assign(missing.values)
      self
    end

    # The picture for a value of a field (VALUE_FIELDS), given as one or more spellings (an entity's variants), or nil
    def value(field, *spellings) = pick([ field, spellings ])

    # The picture for a period (Browse::Periods::Period: a first and last year; the earliest has no first)
    def period(period) = pick(period)

    private

    # After #prepare every value has its picture already (or none); without it, each takes the next free one as it is asked for
    def pick(want) = @assigned&.key?(want) ? @assigned[want] : take(want)

    # Every value's picture at once, the values with the fewest pictures choosing first (a maker with three pictures before Paris with
    # hundreds), so a value's few pictures are not taken by one that had others; never a record the page shows elsewhere (its Discover)
    def assign(wants)
      options = wants.to_h do |want|
        own = @documents.select { |document| !@avoid.include?(document["id"]) && carries?(document, want) }
        far = Array(@elsewhere[want]).reject { |picture| @avoid.include?(picture["id"]) }
        # a record whose first value is this one (its main maker, its image's biggest colour) before one that only mentions it
        [ want, (own + far).uniq { |picture| picture["id"] }.each_with_index.sort_by { |picture, index| [ leading?(picture, want) ? 0 : 1, index ] }.map(&:first) ]
      end
      @assigned = {}
      wants.sort_by.with_index { |want, index| [ options[want].size, index ] }.each do |want|
        found = options[want].find { |picture| !used?(picture) }
        use(found) if found
        @assigned[want] = found && Picture.new(id: found["id"], src: found["src"])
      end
    end

    def carries?(document, want)
      if want.is_a?(Array)
        document[want.first].intersect?(want.last)
      else
        (year = document["year"]) && year <= want.last && (want.first.nil? || year >= want.first)
      end
    end

    def leading?(picture, want) = want.is_a?(Array) && want.last.include?(Array(picture[want.first]).first)

    def query(want)
      return Browse.field_query(want.first, want.last) if want.is_a?(Array)

      "date_start_isi:[#{want.first || '*'} TO #{want.last}]"
    end

    # { solr query => [{ "id", "src" }, ...] } from one grouped request (a group for each query), or nil when Solr cannot answer
    def elsewhere(queries)
      response = (@repository || Blacklight.default_index).search(params: { q: "*:*", defType: "lucene", qt: "select", fq: Cards::THUMBNAIL_FILTERS, rows: 0,
                                                                              fl: FIELDS.join(","), facet: false, group: true, "group.query": queries,
                                                                              "group.limit": ELSEWHERE * 2, "group.sort": "id asc" })
      queries.to_h do |solr_query|
        docs = Array(response.dig("grouped", solr_query, "doclist", "docs")).map { |hash| SolrDocument.new(hash) }
        pictures = docs.select { |document| AccessPolicy.view?(document) && !Sensitivity.sensitive?(document) && document["thumbnail_path_ssi"].present? }
        [ solr_query, pictures.first(ELSEWHERE).map { |document| { "id" => document.id.to_s, "src" => document["thumbnail_path_ssi"].to_s, **VALUE_FIELDS.to_h { |field| [ field, Array(document[field]) ] } } } ]
      end
    rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable => e
      Rails.logger.warn("Facet pictures elsewhere unavailable: #{e.class}")
      nil
    end

    # The page's own records not shown elsewhere on it first, then the value's records anywhere, and a record the page's Discover shows
    # only when there is nothing else; no record, and no picture, twice
    def take(want)
      free = @documents.reject { |document| used?(document) }.select { |document| carries?(document, want) }
      found = free.find { |document| !@avoid.include?(document["id"]) }
      found ||= Array(@elsewhere[want]).find { |picture| !used?(picture) && !@avoid.include?(picture["id"]) }
      found ||= free.first
      return unless found

      use(found)
      Picture.new(id: found["id"], src: found["src"])
    end

    public

    # Pictures of the page's own records that nothing else on it shows (its Discover records and its tiles' pictures excluded), for the
    # strip at its head: at most `count`, each used up
    def spare(count)
      @documents.reject { |document| used?(document) || @avoid.include?(document["id"]) }.first(count).each { |document| use(document) }
                .map { |document| Picture.new(id: document["id"], src: document["src"]) }
    end

    private

    def used?(picture) = @used.include?(picture["id"]) || @used.include?(picture["src"])

    def use(picture)
      @used << picture["id"] << picture["src"]
    end
  end
end
