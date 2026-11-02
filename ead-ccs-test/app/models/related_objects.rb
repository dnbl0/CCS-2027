# frozen_string_literal: true

# The "Related objects" on a record page: other records that share what this one is, who made it, what it is about or where
# it comes from. A record with an image ranks above one without; the same collection only nudges the order, it is not a reason
# to relate two records. The answer is kept for a day for each record (an answer that failed is not kept).
module RelatedObjects
  LIMIT = 6
  # field => how much a match counts towards the order; these fields also decide which records are related
  SIGNALS = { "object_type_ssim" => 4, "creator_ssim" => 3, "subject_ssim" => 2, "production_place_ssim" => 2 }.freeze
  NUDGE = { "collection_ssim" => 1, "has_digital_asset_bsi" => 2 }.freeze
  PER_FIELD = 3
  UNKNOWN_MAKER = "Unknown"

  # document: a SolrDocument; connection: the Solr connection to ask (the tests pass their own)
  def self.for(document, connection = nil, limit: LIMIT)
    clauses = SIGNALS.flat_map { |field, boost| values(document, field).map { |value| [ field, value, boost ] } }
    return [] if clauses.empty?

    Rails.cache.fetch("related_objects/v1/#{document.id}", expires_in: 1.day, skip_nil: true) do
      RecordSummaries.fetch(params(document, clauses, limit), connection)
    end.to_a.map { |fields| SolrDocument.new(fields) }
  end

  def self.values(document, field)
    Array(document[field]).map(&:to_s).compact_blank.reject { |value| field == "creator_ssim" && value == UNKNOWN_MAKER }.first(PER_FIELD)
  end

  def self.params(document, clauses, limit)
    required = clauses.map { |field, value, _boost| "#{field}:#{RecordSummaries.phrase(value)}" }
    scored = clauses.map { |field, value, boost| "#{field}:#{RecordSummaries.phrase(value)}^#{boost}" }
    scored += values(document, "collection_ssim").map { |value| "collection_ssim:#{RecordSummaries.phrase(value)}^#{NUDGE['collection_ssim']}" }
    scored << "has_digital_asset_bsi:true^#{NUDGE['has_digital_asset_bsi']}"
    { q: scored.join(" OR "), fq: [ "-id:#{RecordSummaries.phrase(document.id)}", required.join(" OR ") ], rows: limit, sort: "score desc, id asc" }
  end

  private_class_method :values, :params
end
