# frozen_string_literal: true

# What a visitor may do with a record's digital assets, decided from the record's licence (CCS-67, CCS-69).
# The DAM's own classification is not in the index yet, so the rules read licence_type_ssim; they live here, in one
# place, so the real classification can replace them.
#
#   :open     view and download                    (CCS-67: "View and download")
#   :view_only view, but not download; download on request (the "Licenced / Permissioned" class)
#   :request   not viewable; view on request and approval (CCS-69: "Not licenced")
module AccessPolicy
  TIERS = %i[open view_only request].freeze

  # document: a SolrDocument. Returns one of TIERS.
  def self.tier(_document) = :open

  # Where a visitor asks for access to a record (the access request form, app/controllers/access_requests_controller.rb)
  def self.request_path(document) = "/access_requests/new?document_id=#{ERB::Util.url_encode(document.id)}"
end
