# frozen_string_literal: true

module Dam
  # Writes the DAM assets in dam_assets (DamAsset) into the index fields the app already reads, as Solr atomic updates, for
  # the records whose DAM fields changed only (a digest of the fields, dam_digest_ssi, says whether they did).
  #
  # It writes only to DAM_SOLR_URL, a core of its own (a copy of the shared index: rake dam:copy_index), never the shared
  # core: an atomic update rewrites the whole document, and a field that is indexed but not stored would be lost.
  #
  # A record matches an asset by accession number. When two records share an accession number (Grainger and the Art
  # Collection both have a 0.0013), an asset goes to the record of its own collection (cACollection1), or to both when it
  # names none. Deleted assets are left out; a record left with none has its DAM fields removed.
  class SolrWriter
    # dam_licence_ssim (the License type filter) and dam_access_tier_ssi (the Digital asset Access Condition filter and the
    # Open licence switch, FreeReuse) are for searching: the record page reads digital_asset_metadata_ssm through AccessPolicy.
    # The image and media fields hold the viewable assets only (AccessPolicy.asset_tiers), so no address of a withheld asset is
    # in the index; digital_asset_download_paths_ssim holds the addresses of the open ones (AccessPolicy.download_path?).
    FIELDS = %w[digital_asset_metadata_ssm thumbnail_path_ssi digital_asset_paths_ssim digital_asset_large_paths_ssim
                digital_media_ssim digital_asset_download_paths_ssim has_digital_asset_bsi digital_asset_format_ssim dam_licence_ssim
                dam_access_tier_ssi dam_digest_ssi].freeze
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
    # Each asset has its own tier (AccessPolicy.asset_tiers: its own DAM licence, and an EMu restriction withholds them all). Only
    # the viewable ones (:open, :view_only) go in the image and media fields, in display order; digital_asset_metadata_ssm keeps
    # every asset, with its tier, so the record page can say what is withheld and why.
    # has_digital_asset_bsi: at least one asset is viewable (results sort those first and the "With Digital Asset" filter reads
    # it). dam_access_tier_ssi: the most permissive asset tier (AccessPolicy.tier). When the DAM's licence changes, the next sync
    # changes them.
    def self.fields_for(assets, record = {})
      return FIELDS.index_with { nil } if assets.empty?

      document = SolrDocument.new(record.slice(*POLICY_FIELDS).merge("id" => record["id"], "digital_asset_metadata_ssm" => assets.map { |asset| metadata(asset) }))
      tiers = AccessPolicy.asset_tiers(document)
      tier_of = assets.zip(tiers).to_h
      viewable = assets.select { |asset| tier_of[asset] != :request }
      open = viewable.select { |asset| tier_of[asset] == :open }
      images = viewable.select { |asset| image?(asset) }
      media = viewable.select { |asset| media?(asset) }
      fields = {
        "dam_licence_ssim" => assets.map { |asset| asset.licence.to_s.strip }.reject { |licence| AccessPolicy::DAM_NO_LICENCE.include?(licence.downcase) }
                                    .uniq.sort.presence,
        "dam_access_tier_ssi" => AccessPolicy.tier(document).to_s,
        "digital_asset_metadata_ssm" => assets.map { |asset| metadata(asset, tier_of[asset]) },
        "thumbnail_path_ssi" => images.first&.urls&.dig("thumbnail") || images.first&.urls&.dig("large"),
        "digital_asset_paths_ssim" => images.map { |asset| asset.urls["thumbnail"].presence || asset.urls["large"] }.presence,
        "digital_asset_large_paths_ssim" => images.map { |asset| asset.urls["large"] }.presence,
        "digital_media_ssim" => media.map { |asset| media_entry(asset) }.presence,
        "digital_asset_download_paths_ssim" => (open.select { |asset| image?(asset) }.map { |asset| asset.urls["large"] } +
                                                open.select { |asset| media?(asset) }.map { |asset| asset.urls["original"] }).presence,
        "has_digital_asset_bsi" => images.any? || media.any?,
        "digital_asset_format_ssim" => assets.filter_map { |asset| FORMATS[asset.format_type] }.uniq.presence
      }
      fields.merge("dam_digest_ssi" => Digest::SHA256.hexdigest(fields.to_json))
    end

    def self.image?(asset) = asset.format_type == "image" && asset.urls["large"].present?
    def self.media?(asset) = MEDIA_KINDS.include?(asset.format_type) && asset.urls["original"].present?

    # tier: the asset's own (AccessPolicy.asset_tiers), kept with its metadata so the page can tell a withheld asset from a shown one
    def self.metadata(asset, tier = nil)
      { "dam_id" => asset.dam_id, "filename" => asset.filename, "format" => asset.format_type, "licence" => asset.licence,
        "advisory" => asset.advisory, "terms_of_use" => asset.terms_of_use, "producer" => asset.producer, "tier" => tier&.to_s }.compact.to_json
    end

    def self.media_entry(asset)
      type = Rack::Mime.mime_type(File.extname(asset.filename.to_s), "application/octet-stream")
      [ asset.format_type, type, asset.urls["original"], asset.filename.to_s.tr("|", " ") ].join("|")
    end

    private

    def find(accessions)
      terms = accessions.map { |accession| %("#{accession.gsub(/["\\]/) { |c| "\\#{c}" }}") }.join(" OR ")
      response = @solr.get("select", params: { q: "accession_number_ssim:(#{terms})", fl: "id,accession_number_ssim,collection_ssim,dam_digest_ssi,#{POLICY_FIELDS.join(',')}",
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
      return nil if mine.empty? && doc["dam_digest_ssi"].blank?

      fields = self.class.fields_for(mine.uniq, doc)
      return nil if fields["dam_digest_ssi"] == doc["dam_digest_ssi"]

      { "id" => doc["id"] }.merge(fields.transform_values { |value| { "set" => value } })
    end
  end
end
