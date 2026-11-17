# frozen_string_literal: true

# How a filter's stored values read on the page (Blacklight's facet helper_method, CatalogConfig::Facets::VALUE_HELPERS)
module FacetValuesHelper
  # "open", "view_only", "request" (dam_access_tier_ssi, AccessPolicy tiers) in the record page's own words
  def access_tier_facet_label(value) = t("nexus_ccs.record_page.access.#{value}", default: value.to_s.humanize)
end
