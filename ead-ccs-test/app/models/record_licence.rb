# frozen_string_literal: true

# The licence a page shows for a record's images, the same on every page (the record page's media, its Use and access, Compare): the
# Nexus DAM's licence (CCS-400: the DA licence type comes from the DAM), a shown asset's before a withheld one's, else the collection
# system's licence (licence_type_ssim) for a record without DAM assets. Only for showing: AccessPolicy decides what a visitor may do,
# and the IIIF manifest maps the collection system's licence names to rights statements.
module RecordLicence
  module_function

  def for(document)
    dam_licence(document) || Array(document["licence_type_ssim"]).first.to_s.strip.presence
  end

  def dam_licence(document)
    assets = Array(document["digital_asset_metadata_ssm"]).filter_map do |json|
      parsed = JSON.parse(json.to_s)
      parsed if parsed.is_a?(Hash)
    rescue JSON::ParserError
      nil
    end
    tiers = AccessPolicy.asset_tiers(document) || []
    shown, withheld = assets.each_with_index.partition { |_asset, index| tiers[index] && tiers[index] != :request }
    (shown + withheld).map(&:first).filter_map { |asset| asset["licence"].to_s.strip.presence }.first
  end
end
