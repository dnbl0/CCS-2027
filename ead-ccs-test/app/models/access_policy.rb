# frozen_string_literal: true

# What a visitor may do with a record's digital assets, decided from the record's licence (CCS-67, CCS-69).
# The DAM's own classification is not in the index yet, so the rules read licence_type_ssim; they live here, in one
# place, so the real classification can replace them (change TIER_BY_LICENCE and .tier; nothing else reads the licence).
# Metadata is shown on every tier; only the asset (image, audio, video, PDF) is gated.
#
#   :open      view and download                    (CCS-67: "View and download")
#   :view_only view, but not download; download on request (the "Licenced / Permissioned" class)
#   :request   not viewable; view on request and approval (CCS-69: "Not licenced")
#
# licence_type_ssim (records in the index)    tier        why
#   Public domain - Copyright expired   4005  :open       no rights remain to protect
#   Copyright - Current                 3421  :view_only the University does not hold the right to give copies away
#   Copyright                            587  :view_only as above
#   Reproduction Licence - Current      1760  :view_only a licence covers set uses, so a copy is given on request
#   Reproduction Licence - Requested      33  :view_only no licence yet, but nothing says the image is sensitive
#   Reproduction Licence - The University of Melbourne 13  :view_only the University's own licence, still by request
#   Reproduction Licence - Restricted      1  :request   the licence itself restricts use
#   Restricted Access                      2  :request   the record says access is restricted
#   ICIP Rights                           29  :request   Indigenous Cultural and Intellectual Property: the community
#                                                        decides who sees it (a request is how that decision is asked for)
#   blank (no licence)               31111  :view_only unknown, so never downloadable; but withholding would hide the
#                                                        images of most of the collection for a gap in the data
#   any value not listed above                :view_only as for blank, unless it says "restricted" or "ICIP" (:request)
#
# A record whose access condition (access_condition_ssi) is "Community Restricted" (1 record) is :request whatever its
# licence: access is limited to a community, so a visitor is not offered a "view anyway" choice (Sensitivity is for
# material that may be shown if the visitor chooses).
#
# A record with several EMu licences gets the most restrictive tier.
#
# DAM usage rights decide, asset by asset (TIER_BY_DAM_LICENCE, .asset_tiers); the EMu licence table is the fallback for a record
# with no DAM data, and a record-level gate:
#
#   each DAM asset                               its own tier, from its own DAM licence (blank or "None": :request)
#   EMu licence :request (ICIP, restricted) or   every asset of the record is :request, whatever the DAM says
#     access condition "Community Restricted"
#   what a record shows                          the assets whose own tier is :open or :view_only; the rest are withheld
#   what a record offers to download             the assets whose own tier is :open (.download_path?)
#   the record's tier (.tier)                    the most permissive of its assets' tiers: :open when at least one asset is
#                                                open, :request only when every asset is withheld
#
# Dam::SolrWriter writes the image and media fields of the index with the viewable assets only (no address of a withheld asset
# is in the index), digital_asset_download_paths_ssim with the open ones, and dam_access_tier_ssi with .tier (the Digital asset
# Access Condition filter, and the Open licence switch, FreeReuse: "has at least one open asset"). The University agreed on
# 2026-11-18 that a licensed asset is shown even when another asset of the same record is not.
#
# (Earlier note) Swapping in the DAM: the ingest keeps each asset's full DAM metadata in the Solr field assets_json. The fields likely to
# carry the real classification are metadata.dAUseStatus (fixture value "Requires Action"; real values not yet known),
# dAAdvisory1, dAShareWithCMS, and security.release_date / expiration_date / asset_groups (released_and_not_expired).
# The rules to replace are TIER_BY_LICENCE, WITHHELD and .tier (the "licence rules"); .view?, .download? and
# .request_path, and everything that shows or links an asset, only ask for the tier.
module AccessPolicy
  TIERS = %i[open view_only request].freeze

  TIER_BY_LICENCE = {
    "public domain - copyright expired" => :open,
    "copyright - current" => :view_only,
    "copyright" => :view_only,
    "reproduction licence - current" => :view_only,
    "reproduction licence - requested" => :view_only,
    "reproduction licence - the university of melbourne" => :view_only,
    "reproduction licence - restricted" => :request,
    "restricted access" => :request,
    "icip rights" => :request
  }.freeze

  # A wording not in the table that still says the asset is restricted is withheld, not shown
  WITHHELD = /restricted|icip/

  # Access conditions (access_condition_ssi, compared in lower case) that withhold the asset whatever the licence
  WITHHELD_ACCESS_CONDITIONS = [ "community restricted" ].freeze

  # The DAM's usage rights are the source of truth (digital_asset_metadata_ssm: one JSON object per asset, with a "licence").
  # Compared in lower case. A blank licence (the DAM has none, or "None") is not cleared for display, so it is :request.
  # The last five (seen in the DAM on 2026-11-17) are placeholders until the University confirms them: free-to-reuse statements
  # are open; the non-commercial Creative Commons licences are view only for now (the cautious choice).
  TIER_BY_DAM_LICENCE = {
    "cc by" => :open,
    "all rights reserved (uom)" => :view_only,
    "copyright agency limited" => :view_only,
    "individual" => :view_only,
    "public domain" => :open,
    "no known copyright" => :open,
    "cc0" => :open,
    "cc by-nc" => :view_only,
    "cc by-nc-sa" => :view_only
  }.freeze
  DAM_NO_LICENCE = [ "", "none" ].freeze

  # The index field with the addresses of the record's open assets (large images and media files), written by Dam::SolrWriter
  DOWNLOAD_PATHS_FIELD = "digital_asset_download_paths_ssim"

  # document: a SolrDocument. Returns one of TIERS: the most permissive of the record's assets' tiers (.asset_tiers), so a record
  # with one open asset is :open and one whose assets are all withheld is :request. A record whose index has no DAM usage rights
  # at all falls back to the EMu licence rules.
  def self.tier(document)
    tiers = asset_tiers(document)
    return (withheld_by_access_condition?(document) ? :request : emu_tier(document)) if tiers.nil?

    tiers.min_by { |tier| TIERS.index(tier) }
  end

  # Each DAM asset's own tier, in the order of digital_asset_metadata_ssm, or nil when the record carries no DAM usage rights.
  # An EMu restriction (ICIP, restricted, community restricted) makes every asset :request: the DAM can never open those up.
  def self.asset_tiers(document)
    licences = dam_licences(document)
    return nil if licences.nil?
    return Array.new(licences.size, :request) if withheld_by_access_condition?(document) || emu_tier(document) == :request

    licences.map { |licence| dam_tier_of(licence) }
  end

  # How many of the record's DAM assets are withheld while others are shown (0 when nothing is withheld, and 0 when everything
  # is: that record has the request notice in place of its media)
  def self.withheld_assets(document)
    tiers = asset_tiers(document)
    return 0 if tiers.nil? || tiers.all?(:request)

    tiers.count(:request)
  end

  # May the file at this address (a large image or a media file, as indexed, without a version token) be downloaded? Only an
  # open asset's: for a record with DAM data the addresses in DOWNLOAD_PATHS_FIELD, for one without, every file of an :open record.
  def self.download_path?(document, url)
    return false unless download?(document)
    return true if dam_licences(document).nil?

    Array(document[DOWNLOAD_PATHS_FIELD]).include?(url.to_s)
  end

  def self.emu_tier(document)
    licences = Array(document["licence_type_ssim"]).map { |value| value.to_s.strip.downcase }.compact_blank
    return :view_only if licences.empty?

    licences.map { |licence| tier_of(licence) }.max_by { |tier| TIERS.index(tier) }
  end
  private_class_method :emu_tier

  # The DAM licence of each asset (lower case, "" when blank), or nil when the record carries no DAM usage rights
  def self.dam_licences(document)
    values = Array(document["digital_asset_metadata_ssm"]).filter_map do |json|
      parsed = JSON.parse(json.to_s)
      parsed.is_a?(Hash) ? parsed["licence"].to_s.strip.downcase : nil
    rescue JSON::ParserError
      nil
    end
    values.presence
  end
  private_class_method :dam_licences

  def self.dam_tier_of(licence)
    return :request if DAM_NO_LICENCE.include?(licence)

    TIER_BY_DAM_LICENCE.fetch(licence) { licence.match?(WITHHELD) ? :request : :view_only }
  end
  private_class_method :dam_tier_of

  def self.tier_of(licence)
    TIER_BY_LICENCE.fetch(licence) { licence.match?(WITHHELD) ? :request : :view_only }
  end
  private_class_method :tier_of

  def self.withheld_by_access_condition?(document)
    Array(document["access_condition_ssi"]).any? { |value| WITHHELD_ACCESS_CONDITIONS.include?(value.to_s.strip.downcase) }
  end
  private_class_method :withheld_by_access_condition?

  # The licences (lower case, as in TIER_BY_LICENCE) that give a record this tier. FreeReuse reads :open from here, so the
  # "free reuse" filter follows the same rules as the download button. Replace with the DAM classification when .tier is.
  def self.licences_with_tier(tier) = TIER_BY_LICENCE.select { |_licence, licence_tier| licence_tier == tier }.keys

  # The access conditions (lower case) that withhold a record's asset whatever its licence
  def self.withheld_access_conditions = WITHHELD_ACCESS_CONDITIONS

  # Is the record's first image (the one its thumbnail shows) an open asset? For the places that give the image away as the
  # record's picture (the Pick of the day, structured data): another asset of the record being open is not enough.
  def self.first_image_open?(document)
    download_path?(document, Array(document["digital_asset_large_paths_ssim"]).first)
  end

  # At least one asset may be shown (:open, :view_only)
  def self.view?(document) = tier(document) != :request

  # At least one asset may be downloaded (:open only); which ones: .download_path?
  def self.download?(document) = tier(document) == :open

  # Where a visitor asks for access to a record (the access request form, app/controllers/access_requests_controller.rb)
  def self.request_path(document) = "/access-requests/new?document_id=#{ERB::Util.url_encode(document.id)}"
end
