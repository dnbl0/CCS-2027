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
# A record with several licences gets the most restrictive tier.
#
# Swapping in the DAM: the ingest keeps each asset's full DAM metadata in the Solr field assets_json. The fields likely to
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

  # document: a SolrDocument. Returns one of TIERS.
  def self.tier(document)
    return :request if withheld_by_access_condition?(document)

    licences = Array(document["licence_type_ssim"]).map { |value| value.to_s.strip.downcase }.compact_blank
    return :view_only if licences.empty?

    licences.map { |licence| tier_of(licence) }.max_by { |tier| TIERS.index(tier) }
  end

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

  # The asset may be shown (:open, :view_only)
  def self.view?(document) = tier(document) != :request

  # The asset may be downloaded (:open only)
  def self.download?(document) = tier(document) == :open

  # Where a visitor asks for access to a record (the access request form, app/controllers/access_requests_controller.rb)
  def self.request_path(document) = "/access_requests/new?document_id=#{ERB::Util.url_encode(document.id)}"
end
