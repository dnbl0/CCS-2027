# frozen_string_literal: true

# One Nexus DAM asset, as Dam::Sync last read it. The DAM metadata fields behind the record page's media metadata
# (config/data_model/field_labels.json rows 27-30) and the record match, checked against the DAM's own field list on 2026-11-17:
#
#   accession_number  cAAccessionNumber   "CA Accession Number" (the record's accession_number_ssim)
#   licence           dALicenseType       "DA License Type" (AccessPolicy::TIER_BY_DAM_LICENCE)
#   advisory          dAAdvisory1         "DA Advisory"
#   terms_of_use      dAAssetRights       "DA Terms of Use"
#   producer          dACreatorNameRole   "DA Creator Name (Role)": the nearest field to "Producer"; to be confirmed by the dev team
#   collection        cACollection1       tells two records with the same accession number apart
#   display_sequence  dAwebdisplaysequence the order of a record's images
#
# Images are linked, not copied: urls holds the DAM's embed links, which do not expire (the signed preview links under
# "thumbnails" do, after about a day, so they are not used).
class DamAsset < ApplicationRecord
  FIELDS = {
    accession_number: "cAAccessionNumber", collection: "cACollection1", licence: "dALicenseType", advisory: "dAAdvisory1",
    terms_of_use: "dAAssetRights", producer: "dACreatorNameRole", display_sequence: "dAwebdisplaysequence"
  }.freeze

  # The DAM embed each kind of link is read from, by the asset's format type (as the dev team's ingest does)
  THUMBNAIL_EMBED = { "image" => "1000x1000_without_retina", "pdf" => "document_thumbnail", "office" => "document_thumbnail",
                      "video" => "video_poster" }.freeze
  LARGE_EMBED = { "image" => "2000xauto_without_retina" }.freeze

  scope :live, -> { where(deleted_at: nil) }
  scope :in_display_order, -> { order(Arel.sql("display_sequence IS NULL, display_sequence, filename, dam_id")) }

  # The columns for one asset from the DAM API (an item of /v2/assets/search with metadata, file_properties and embeds)
  def self.attributes_from_api(item)
    fields = item.dig("metadata", "fields") || {}
    value = ->(key) { Array(fields[key]).map { |text| text.to_s.strip }.compact_blank.join("; ").presence }
    format_type = item.dig("file_properties", "format_type")
    embeds = item["embeds"] || {}
    url = ->(name) { embeds.dig(name, "url") if name }

    {
      dam_id: item.fetch("id"),
      filename: item["filename"],
      format_type: format_type,
      **FIELDS.except(:display_sequence).to_h { |column, key| [ column, value.(key) ] },
      display_sequence: Integer(value.(FIELDS[:display_sequence]).to_s, exception: false),
      urls: { "thumbnail" => url.(THUMBNAIL_EMBED[format_type]), "large" => url.(LARGE_EMBED[format_type]), "original" => url.("original") }.compact,
      dam_updated_at: item["last_update_date"],
      deleted_at: item["deleted_date"]
    }
  end
end
