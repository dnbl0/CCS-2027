# frozen_string_literal: true

# What the discovery sections (Similar records, Featured, Trending, Pick of the day) share: which records may be listed in
# them, the fields they ask Solr for, and how they read Solr. Every request goes through the repository's #search (never the
# real-time get handler), so the sections are served from the same place as a results page and a test can answer them with
# CannedSearch.
#
# Which records are listed. A record whose asset is withheld (AccessPolicy :request) or sensitive (Sensitivity) is left out of
# every section: the sections are a shop window, so nothing in them should need the visitor's choice first. (Its own record
# page and the search results are unchanged.) The result card is tier-safe as well (no thumbnail for such a record), so this
# is a second lock, not the only one.
module Discovery
  # The fields the cards, the eligibility rules and the similarity query need; not the whole record (assets_json is large)
  FIELDS = %w[
    id title_tsim creator_ssim object_type_ssim collection_ssim format thumbnail_path_ssi has_digital_asset_bsi
    licence_type_ssim access_condition_ssi restrictions_tsi date_start_isi production_date_ssim
  ].freeze

  # May the record be shown in a discovery section at all?
  def self.listable?(document) = !RobotsPolicy.withheld?(document)

  # May the record be the "Pick of the day"? An image anyone may download (AccessPolicy :open) and nothing sensitive
  def self.pickable?(document)
    document["thumbnail_path_ssi"].present? && AccessPolicy.tier(document) == :open && !Sensitivity.sensitive?(document)
  end

  # The records with these ids, in the order given; an id not in the index is left out. One Solr request.
  def self.fetch(ids)
    ids = Array(ids).map(&:to_s).uniq.first(100)
    return [] if ids.empty?

    response = search(q: "{!terms f=id v=$ids}", ids: ids.join(","), rows: ids.size)
    by_id = response.documents.index_by { |document| document.id.to_s }
    ids.filter_map { |id| by_id[id] }
  end

  # One request to the index, with no facets, highlighting or spelling: just records. Returns a Blacklight::Solr::Response.
  def self.search(params)
    base = { defType: "lucene", fl: FIELDS.join(","), facet: false, spellcheck: false, hl: false, wt: "json" }.compact
    Blacklight.default_index.search(params: base.merge(params))
  end

  def self.log_failure(what, error)
    Rails.logger.warn("#{what} unavailable: #{error.class}: #{error.message}")
  end
end
