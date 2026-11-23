# frozen_string_literal: true

module Browse
  # A picture for each value in an entity page's "ways in" (its kinds of record, periods, places, makers and subjects), so those sections
  # can be the same picture mosaic as the rest of the page instead of lists of chips. ONE Solr request for the entity's records that have
  # a picture that may be shown (Browse::Cards::THUMBNAIL_FILTERS: a thumbnail, not sensitive, not restricted; AccessPolicy.view? checked
  # here too), kept for a day; each value then takes the first of those records that carries it, and no picture is used twice on the page.
  # A value none of them carries has no picture (its tile is text only).
  class FacetPictures
    ROWS = 400
    # the fields whose values the sections show (an entity page's, and a collection or theme page's eras and named collections)
    VALUE_FIELDS = %w[object_type_ssim creator_ssim production_place_ssim subject_ssim date_era_ssim named_collection_ssim].freeze
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

    def initialize(documents, avoid = [])
      @documents = documents
      @avoid = avoid.to_set(&:to_s)
      @used = Set.new
    end

    # The picture for a value of a field (VALUE_FIELDS), given as one or more spellings (an entity's variants), or nil
    def value(field, *spellings) = take { |document| document[field].intersect?(spellings) }

    # The picture for a period (Browse::Periods::Period: a first and last year; the earliest has no first)
    def period(period) = take { |document| (year = document["year"]) && year <= period.last && (period.first.nil? || year >= period.first) }

    private

    def take
      free = @documents.reject { |document| @used.include?(document["id"]) }.select { |document| yield(document) }
      found = free.find { |document| !@avoid.include?(document["id"]) } || free.first
      return unless found

      @used << found["id"]
      Picture.new(id: found["id"], src: found["src"])
    end
  end
end
