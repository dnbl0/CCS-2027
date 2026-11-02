# frozen_string_literal: true

# A record's metadata as a CSV download (CCS-163), for a record in the :open tier (public domain) only. For any other record
# the address is a 404, as if there were no export: the page does not offer it either (NexusCcs::MetadataExportComponent).
class MetadataExportsController < ApplicationController
  include RecordLookup

  def show
    document = find_record(params[:id])
    raise ActionController::RoutingError, "Not Found" unless AccessPolicy.download?(document)

    export = RecordCsv.new(document, show_fields: show_fields, persistent_link: solr_document_url(document))
    send_data export.to_csv, type: "text/csv; charset=utf-8", disposition: "attachment", filename: export.filename
  end

  private

  def show_fields = CatalogController.blacklight_config.show_fields.values.map { |config| [ config.label, config.field ] }
end
