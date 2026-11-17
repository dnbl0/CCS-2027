# frozen_string_literal: true

module Dam
  # Writes the DAM assets in dam_assets (DamAsset) into the index fields the app already reads, as Solr atomic updates, for
  # the records whose DAM fields changed only (a digest of the fields, dam_digest_ss, says whether they did).
  #
  # It writes only to DAM_SOLR_URL, a core of its own (a copy of the shared index: rake dam:copy_index), never the shared
  # core: an atomic update rewrites the whole document, and a field that is indexed but not stored would be lost.
  #
  # A record matches an asset by accession number. When two records share an accession number (Grainger and the Art
  # Collection both have a 0.0013), an asset goes to the record of its own collection (cACollection1), or to both when it
  # names none. Deleted assets are left out; a record left with none has its DAM fields removed.
  class SolrWriter
    FIELDS = %w[digital_asset_metadata_ssm thumbnail_path_ssi digital_asset_paths_ssim digital_asset_large_paths_ssim
                digital_media_ssim has_digital_asset_bsi digital_asset_format_ssim dam_digest_ss].freeze
    # The Format facet's values (digital_asset_format_ssim), by DAM format type; other types are not shown
    FORMATS = { "image" => "Image", "audio" => "Audio", "video" => "Video", "pdf" => "PDF" }.freeze
    # Audio, video and PDF go in digital_media_ssim ("kind|type|url|label", Collections::DigitalMedia)
    MEDIA_KINDS = %w[audio video pdf].freeze
    BATCH = 100

    def self.from_env
      url = ENV["DAM_SOLR_URL"].presence
      raise Error, "DAM_SOLR_URL is not set: the DAM sync writes only to a core of its own (docs/dam-sync.md)" unless url

      new(solr: RSolr.connect(url: url))
    end

    def initialize(solr:)
      @solr = solr
    end

    # accessions: the accession numbers whose assets may have changed. Returns how many records were updated.
    def write(accessions)
      updated = 0
      accessions.to_a.compact.uniq.each_slice(BATCH) do |slice|
        documents = find(slice)
        shared = documents.flat_map { |doc| Array(doc["accession_number_ssim"]) }.tally
        assets = DamAsset.live.where(accession_number: slice).in_display_order.group_by(&:accession_number)
        updates = documents.filter_map { |doc| update_for(doc, assets, shared) }
        next if updates.empty?

        @solr.add(updates)
        updated += updates.size
      end
      @solr.commit if updated.positive?
      updated
    end

    # The record fields AccessPolicy reads besides the DAM's own (an EMu restriction can still withhold an asset)
    POLICY_FIELDS = %w[licence_type_ssim access_condition_ssi].freeze

    # The DAM fields of a record from its assets (nil values when it has none). record: the record's POLICY_FIELDS.
    # has_digital_asset_bsi says a visitor can see an asset (AccessPolicy.view?), not only that one exists: results sort
    # records with assets first and the "with images" filters read it, and a withheld asset (blank DAM licence: most of the
    # DAM) shows nothing. When the DAM's licence changes, the next sync changes the flag.
    def self.fields_for(assets, record = {})
      return FIELDS.index_with { nil } if assets.empty?

      images = assets.select { |asset| asset.format_type == "image" && asset.urls["large"].present? }
      media = assets.select { |asset| MEDIA_KINDS.include?(asset.format_type) && asset.urls["original"].present? }
      metadata = assets.map { |asset| metadata(asset) }
      viewable = AccessPolicy.view?(SolrDocument.new(record.slice(*POLICY_FIELDS).merge("id" => record["id"], "digital_asset_metadata_ssm" => metadata)))
      fields = {
        "digital_asset_metadata_ssm" => metadata,
        "thumbnail_path_ssi" => images.first&.urls&.dig("thumbnail") || images.first&.urls&.dig("large"),
        "digital_asset_paths_ssim" => images.map { |asset| asset.urls["thumbnail"].presence || asset.urls["large"] }.presence,
        "digital_asset_large_paths_ssim" => images.map { |asset| asset.urls["large"] }.presence,
        "digital_media_ssim" => media.map { |asset| media_entry(asset) }.presence,
        "has_digital_asset_bsi" => viewable && (images.any? || media.any?),
        "digital_asset_format_ssim" => assets.filter_map { |asset| FORMATS[asset.format_type] }.uniq.presence
      }
      fields.merge("dam_digest_ss" => Digest::SHA256.hexdigest(fields.to_json))
    end

    def self.metadata(asset)
      { "dam_id" => asset.dam_id, "filename" => asset.filename, "format" => asset.format_type, "licence" => asset.licence,
        "advisory" => asset.advisory, "terms_of_use" => asset.terms_of_use, "producer" => asset.producer }.compact.to_json
    end

    def self.media_entry(asset)
      type = Rack::Mime.mime_type(File.extname(asset.filename.to_s), "application/octet-stream")
      [ asset.format_type, type, asset.urls["original"], asset.filename.to_s.tr("|", " ") ].join("|")
    end

    private

    def find(accessions)
      terms = accessions.map { |accession| %("#{accession.gsub(/["\\]/) { |c| "\\#{c}" }}") }.join(" OR ")
      response = @solr.get("select", params: { q: "accession_number_ssim:(#{terms})", fl: "id,accession_number_ssim,collection_ssim,dam_digest_ss,#{POLICY_FIELDS.join(',')}",
                                               rows: accessions.size * 5, wt: "json" })
      response.dig("response", "docs") || []
    end

    def update_for(doc, assets_by_accession, shared)
      collections = Array(doc["collection_ssim"]).map { |name| name.to_s.downcase }
      mine = Array(doc["accession_number_ssim"]).flat_map do |accession|
        assets = assets_by_accession.fetch(accession, [])
        next assets unless shared[accession].to_i > 1

        assets.select { |asset| asset.collection.blank? || collections.include?(asset.collection.downcase) }
      end
      return nil if mine.empty? && doc["dam_digest_ss"].blank?

      fields = self.class.fields_for(mine.uniq, doc)
      return nil if fields["dam_digest_ss"] == doc["dam_digest_ss"]

      { "id" => doc["id"] }.merge(fields.transform_values { |value| { "set" => value } })
    end
  end
end
