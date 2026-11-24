# frozen_string_literal: true

# One colour's wall on Explore by colour (ColoursController#index with ?colour=; after Google Arts & Culture's Color Explorer, looked at
# 2026-11-24): records whose images have that colour, as square pictures. One Solr request for up to POOL pictured records that may be
# shown (Browse::Cards::THUMBNAIL_FILTERS, AccessPolicy, not sensitive), kept for a day; those whose image has the colour as its biggest
# share come first (colour_ssim is ranked, the biggest first), so the wall reads as that colour; then the rest, by id.
module ColourRecords
  Record = Data.define(:id, :title, :src)
  SHOWN = 45 # Google's first screenful: nine rows of five
  POOL = 150
  FIELDS = %w[id title_tsim thumbnail_path_ssi colour_ssim].freeze

  module_function

  # [Record], at most SHOWN; [] when the colour has none; nil when Solr cannot answer
  def for(name, repository: nil)
    field = CatalogConfig::Facets::COLOUR_FIELD
    records = Rails.cache.fetch(SuppressedRecord.cache_key("colour_records/v1/#{name}"), expires_in: 1.day, skip_nil: true) do
      response = (repository || Blacklight.default_index).search(params: {
        q: "*:*", defType: "lucene", qt: "select", fq: [ Browse.field_query(field, [ name ]) ] + Browse::Cards::THUMBNAIL_FILTERS,
        rows: POOL, sort: "id asc", fl: (Browse::Profile::FIELDS + FIELDS).uniq.join(","), facet: false
      })
      shown = response.documents.select { |document| AccessPolicy.view?(document) && !Sensitivity.sensitive?(document) }
      shown.sort_by.with_index { |document, index| [ Array(document[field]).first == name ? 0 : 1, index ] }.first(SHOWN).map do |document|
        { "id" => document.id.to_s, "title" => Array(document["title_tsim"]).first.to_s.strip.presence || "Untitled record", "src" => document["thumbnail_path_ssi"].to_s }
      end
    end
    records&.map { |record| Record.new(id: record["id"], title: record["title"], src: record["src"]) }
  rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable => e
    Rails.logger.warn("Colour records unavailable: #{e.class}")
    nil
  end
end
