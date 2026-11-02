# frozen_string_literal: true

module NexusCcs
  # "Download metadata (CSV)" on a record page (CCS-163). Offered only for a record whose content may be downloaded (the :open
  # tier, AccessPolicy.download?); the export address refuses the rest (MetadataExportsController). A plain link: the response
  # is a file, so the browser downloads it and the page stays. The wording is in config/locales/en.yml (nexus_ccs.metadata_export).
  class MetadataExportComponent < ViewComponent::Base
    def initialize(document:)
      @document = document
    end

    def render? = AccessPolicy.download?(@document)

    def path = helpers.metadata_export_path(@document.id)
  end
end
