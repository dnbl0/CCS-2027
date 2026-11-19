# frozen_string_literal: true

module CatalogConfig
  # The fields of the results list and the record page, from the data model workbook (DataModel).
  module RecordFields
    def self.apply(config)
      # ================================================================
      # Record fields come from the workbook (DataModel): its labels, its order, and only the fields
      # the data can carry. The title is the page heading, so it is not repeated as a field; the
      # results list shows the fields marked `index` in config/data_model/solr_mapping.yml.
      # access_condition_ssi and restrictions_tsi are deliberately absent.
      # ================================================================
      DataModel.fields.select(&:available?).reject { |field| field.seq == 1 }.each do |field|
        config.add_index_field field.solr, label: field.display_label if field.index
        config.add_show_field field.solr, label: field.display_label
      end
    end
  end
end
