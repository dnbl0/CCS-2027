# frozen_string_literal: true

# What a collection, named collection or theme page shows about its records (docs/categories-themes-stories.md), from ONE Solr request:
# the number of records, a few highlights a result card shows a picture for (AccessPolicy.view?, not Sensitivity.sensitive?, the
# shop-window rule of Discovery), and the commonest object types, eras and named collections as links into the search. Kept for six
# hours; nil when Solr cannot answer.
#
#   fq   the Solr filters of the records (built from index values or config/themes.yml, never from visitor text)
module Showcase
  Result = Data.define(:total, :documents, :facets)

  HIGHLIGHTS = 4
  CANDIDATES = 24
  FACET_FIELDS = %w[object_type_ssim date_era_ssim named_collection_ssim].freeze
  FACET_LIMIT = 8
  TTL = 6.hours

  # highlights: how many records to pick (the home page's place walls take more than the landing pages' four)
  def self.call(fq:, first: nil, highlights: HIGHLIGHTS)
    key = "showcase/v1/#{Digest::SHA256.hexdigest([ fq, first, (highlights unless highlights == HIGHLIGHTS) ].flatten.compact.join("\n"))}"
    cached = Rails.cache.fetch(SuppressedRecord.cache_key(key), expires_in: TTL, skip_nil: true) { fetch(Array(fq), first, highlights) }
    cached && Result.new(total: cached["total"], documents: cached["docs"].map { |doc| SolrDocument.new(doc) }, facets: cached["facets"])
  end

  # first: a record id to lead the highlights with (a theme's hero record), when it may be shown
  def self.fetch(fq, first, highlights = HIGHLIGHTS)
    response = SolrGuard.run do
      Discovery.search(q: "*:*", rows: CANDIDATES, sort: "id asc", fq: fq + Categories::IMAGE_FILTERS, facet: true, "facet.mincount": 1,
                       "facet.field": FACET_FIELDS.map { |field| "{!ex=#{Categories::IMAGE_TAG}}#{field}" }, "facet.limit": FACET_LIMIT,
                       "facet.query": "{!ex=#{Categories::IMAGE_TAG} key=all}*:*")
    end
    lead = first.present? ? Discovery.fetch([ first ]) : []
    shown = (lead + response.documents).uniq(&:id).select { |document| shown?(document) }.first(highlights)
    facets = FACET_FIELDS.to_h do |field|
      pairs = response.dig("facet_counts", "facet_fields", field).to_a
      pairs = pairs.each_slice(2).to_a unless pairs.first.is_a?(Array)
      [ field, pairs.reject { |value, _| Browse.noise?(value) }.map { |value, count| [ value, count.to_i ] } ]
    end
    { "total" => response.dig("facet_counts", "facet_queries", "all").to_i, "docs" => shown.map(&:_source), "facets" => facets }
  rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable => e
    Rails.logger.warn("Showcase unavailable: #{e.class}")
    nil
  end

  def self.shown?(document)
    document["thumbnail_path_ssi"].present? && AccessPolicy.view?(document) && !Sensitivity.sensitive?(document) && Discovery.listable?(document)
  end

  private_class_method :fetch
end
