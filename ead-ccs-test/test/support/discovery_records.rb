# frozen_string_literal: true

require_relative "canned_search"

# Records and a stand-in for Solr for the discovery tests (Similar records, Featured, Trending, Pick of the day), so they run in the CI job
# that has no Solr core. The stand-in answers the three kinds of request the discovery code makes: records by id (ids=...), the pool
# for the Pick of the day (a count, then a page), and More Like This (sim_mlt).
module DiscoveryRecords
  include CannedSearch

  THUMB = "/digital-assets/thumbs/85827df9ab6c38d57468e763906aff80.jpg"

  # A record that anyone may see and download
  def open_record(id, **extra)
    { "id" => id, "title_tsim" => [ "Title of #{id}" ], "creator_ssim" => [ "Creator of #{id}" ], "collection_ssim" => [ "University Art Collection" ],
      "licence_type_ssim" => [ "Public domain - Copyright expired" ], "thumbnail_path_ssi" => THUMB, "has_digital_asset_bsi" => true,
      "date_start_isi" => 1900 }.merge(extra.transform_keys(&:to_s))
  end

  def view_only_record(id, **extra) = open_record(id, licence_type_ssim: [ "Copyright - Current" ], **extra)

  # asset withheld (AccessPolicy :request)
  def withheld_record(id, **extra) = open_record(id, licence_type_ssim: [ "ICIP Rights" ], **extra)

  def sensitive_record(id, **extra) = open_record(id, restrictions_tsi: "Culturally sensitive images. Only select images to be published online", **extra)

  # records: every record the index "holds"; similar: ids MLT finds for any record, with the score each has
  def discovery_solr(records:, similar: {})
    by_id = records.index_by { |record| record["id"] }
    lambda do |params|
      params = params.to_h.with_indifferent_access
      if params[:ids]
        docs = params[:ids].split(",").filter_map { |id| by_id[id] }
        canned_response(docs)
      elsif params[:sim_mlt]
        docs = similar.filter_map { |id, score| by_id[id]&.merge("score" => score) }
        canned_response(docs)
      else
        pool = records.select { |record| record["thumbnail_path_ssi"] && record["licence_type_ssim"] == [ "Public domain - Copyright expired" ] }
        pool = pool.sort_by { |record| record["id"] }
        canned_response(pool.drop(params[:start].to_i).first(params[:rows].to_i), total: pool.size)
      end
    end
  end
end
