# frozen_string_literal: true

# Short lists of records for the tiles on other pages (related objects, recently viewed): the few fields a tile and its
# access rules need, from one Solr request. If Solr cannot answer, the list is empty: a page never fails for a tile list.
module RecordSummaries
  # What a tile shows (RecordTilesComponent), and what AccessPolicy and Sensitivity read to decide whether its image may show
  FIELDS = %w[
    id title_tsim object_type_ssim collection_ssim thumbnail_path_ssi has_digital_asset_bsi
    licence_type_ssim access_condition_ssi restrictions_tsi
  ].freeze

  # A Solr phrase: the value in quotes, with any quote or backslash escaped so it cannot change the query
  def self.phrase(value) = %("#{value.to_s.gsub(/["\\]/) { |char| "\\#{char}" }}")

  # An array of hashes (what Solr returned), or nil when Solr could not answer
  def self.fetch(params, connection = nil)
    response = SolrGuard.run do
      (connection || Blacklight.default_index.connection).get("select", params: { fl: FIELDS.join(","), wt: "json" }.merge(params))
    end
    response.dig("response", "docs") || []
  rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable => e
    Rails.logger.warn("Record tiles unavailable: #{e.class}")
    nil
  end
end
