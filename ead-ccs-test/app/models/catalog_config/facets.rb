# frozen_string_literal: true

module CatalogConfig
  # The facets (filters) of the results and the advanced search form, from the data model workbook (DataModel).
  module Facets
    def self.apply(config)
      # ================================================================
      # Facets
      # ================================================================
      # The filters, sections, order (the sheet's # column), names and types come from the workbook (DataModel).
      # Every filter is shown, on the results and in Advanced search (the year selectors as From and To years there). One the data cannot support yet (see
      # config/data_model/solr_mapping.yml) says so in place of values, and is never asked of Solr.
      DataModel.filters.each do |filter|
        # CCS-41 (not in the workbook): the Digital asset option sits above Digital Asset Format Type.
        if filter.name == DIGITAL_ASSET_FORMAT_FILTER
          add_digital_asset_option(config)
          add_free_reuse_option(config)
        end

        unless filter.available?
          config.add_facet_field filter.key, label: filter.name, group: filter.group, include_in_request: false,
            component: NexusCcs::PendingFacetComponent, advanced_search_component: NexusCcs::PendingFacetComponent
          next
        end

        options = { label: filter.name, group: filter.group }
        case filter.type
        when :year then options.merge!(range: true, advanced_search_component: NexusCcs::AdvancedYearRangeComponent) # the range limit plugin's own form and histogram; From and To years in Advanced search
        when :checkbox then options.merge!(limit: nil, filter_class: InclusiveFilterField)
        else options.merge!(limit: 20, index_range: "A".."Z", filter_class: InclusiveFilterField)   # browse, with "search within this filter" in the modal
        end
        config.add_facet_field filter.solr, **options
      end

      add_digital_asset_option(config) unless config.facet_fields.key?("has_digital_asset")
      add_free_reuse_option(config) unless config.facet_fields.key?(FreeReuse::FIELD)

      config.add_facet_fields_to_solr_request!
    end

    # Blacklight's copy_facet_field_config_to_advanced! asks Solr for every filter on the Advanced search form. A filter
    # with no data yet has no Solr field, so it is taken out of that request again.
    def self.keep_pending_out_of_advanced_request(config)
      pending = config.facet_fields.values.select { |facet| facet.component == NexusCcs::PendingFacetComponent }.map(&:field)
      params = config.advanced_search.form_solr_parameters
      params["facet.field"] -= pending
      pending.each { |field| params.delete("f.#{field}.facet.limit") }
    end

    DIGITAL_ASSET_FORMAT_FILTER = "Digital Asset Format Type"

    # CCS-41: show results with or without digital assets. Not in the workbook's filter list, so it is
    # an addition from the Jira story; it sits with the Media type filters.
    def self.add_digital_asset_option(config)
      config.add_facet_field "has_digital_asset", label: "Digital asset", group: "media_type", filter_class: DigitalAssetFilterField, query: {
        with: { label: "With a digital asset", fq: "has_digital_asset_bsi:true" },
        without: { label: "Without a digital asset", fq: "-has_digital_asset_bsi:true" }
      }
    end

    # The "Open licence (public domain)" switch (FreeReuse): not in the workbook either; it sits under Digital asset. A switch, not a
    # list of values, on the results page (NexusCcs::FreeReuseSwitchComponent) and on Advanced search (FreeReuseAdvancedComponent).
    def self.add_free_reuse_option(config)
      config.add_facet_field FreeReuse::FIELD, label: I18n.t("nexus_ccs.free_reuse.facet"), group: "media_type", query: FreeReuse.query_config,
        component: NexusCcs::FreeReuseSwitchComponent, advanced_search_component: NexusCcs::FreeReuseAdvancedComponent
    end
  end
end
