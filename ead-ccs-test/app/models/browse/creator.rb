# frozen_string_literal: true

module Browse
  # The extra facts of a maker's page (docs/browse-and-entities.md, "Richer creator pages"): born and died, nationality and roles, and the
  # makers whose records share this maker's subjects or named collections.
  #
  # The birth, death, nationality and role fields of a record are lists that are not reliably in the same order as its creators, so a
  # fact is only read from a record that names this maker alone; the commonest answer across the page's records wins. Missing fields
  # (a core without nationality_ssim) simply give no fact.
  module Creator
    Facts = Data.define(:born, :died, :nationality, :roles) do
      def any? = [ born, died, nationality ].any? || roles.any?
    end

    RELATED_LIMIT = 8
    TTL = Browse::CACHE_TTL

    def self.facts(entry, documents)
      own = documents.select do |document|
        names = Array(document["creator_ssim"]).map(&:to_s).reject { |name| Browse.noise?(name) }
        names.any? && names.all? { |name| entry.variants.include?(name) }
      end
      Facts.new(born: commonest(own, "creator_birth_isim"), died: commonest(own, "creator_death_isim"),
                nationality: commonest(own, "nationality_ssim"),
                roles: own.flat_map { |document| Array(document["creator_role_ssim"]) }.map(&:to_s).compact_blank.tally.sort_by { |role, n| [ -n, role ] }.map(&:first).first(4))
    end

    # [[value, count], ...] of other makers on records with this maker's commonest subjects or named collections. One facet request,
    # kept for six hours; [] when there is nothing to compare or Solr cannot answer.
    def self.related(entry, facets)
      shared = [ [ "subject_ssim", Array(facets["subject_ssim"]).first(3) ], [ "named_collection_ssim", Array(facets["named_collection_ssim"]).first(2) ] ]
      clauses = shared.filter_map { |field, pairs| SolrQuery.field(field, pairs.map(&:first)) if pairs.any? }
      return [] if clauses.empty?

      Rails.cache.fetch(SuppressedRecord.cache_key("browse/creator_related/v1/#{entry.token}"), expires_in: TTL, skip_nil: true) do
        response = SolrGuard.run do
          Discovery.search(q: "*:*", rows: 0, fq: [ clauses.join(" OR "), "-#{entry.fq}" ], facet: true, "facet.field": "creator_ssim",
                           "facet.limit": RELATED_LIMIT * 2, "facet.mincount": 1, "facet.sort": "count")
        end
        pairs = response.dig("facet_counts", "facet_fields", "creator_ssim").to_a
        pairs = pairs.each_slice(2).to_a unless pairs.first.is_a?(Array)
        pairs.reject { |value, _| Browse.noise?(value) }.map { |value, count| [ value, count.to_i ] }
      rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable => e
        Rails.logger.warn("Related creators unavailable: #{e.class}")
        nil
      end || []
    end

    def self.commonest(documents, field)
      documents.flat_map { |document| Array(document[field]).first(1) }.map(&:to_s).compact_blank.tally.max_by { |value, n| [ n, value ] }&.first
    end

    private_class_method :commonest
  end
end
