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
        # The workbook's "With Digital Asset" (Yes / No) is CCS-41's query facet; the Open licence switch sits under it
        if filter.key == DIGITAL_ASSET_FIELD
          add_digital_asset_option(config, filter)
          add_free_reuse_option(config)
          next
        end

        unless filter.available?
          config.add_facet_field filter.key, label: filter.name, group: filter.group, include_in_request: false,
            component: NexusCcs::PendingFacetComponent, advanced_search_component: NexusCcs::PendingFacetComponent
          next
        end

        options = { label: filter.name, group: filter.group }
        solr = NormalisedTerms.field_for(filter.solr) # Materials / Medium and Nationality: the cleaned-up terms when the core has them
        case filter.type
        when :year then options.merge!(range: true, advanced_search_component: NexusCcs::AdvancedYearRangeComponent) # the range limit plugin's own form and histogram; From and To years in Advanced search
        when :checkbox then options.merge!(limit: nil, **MULTI_SELECT.call(solr))
        else options.merge!(limit: 20, index_range: "A".."Z", **MULTI_SELECT.call(solr))   # browse, with "search within this filter" in the modal
        end
        # FILM COPY: every collection title is listed (config/initializers/film_all_collections.rb); the sidebar shows the first ten and
        # Blacklight's own "More Collection Title" modal the rest, on one page
        options.merge!(limit: 10, more_limit: 40) if filter.solr == "collection_ssim" && ENV["FILM_ALL_COLLECTIONS"].present?
        options[:helper_method] = VALUE_HELPERS[filter.solr] if VALUE_HELPERS.key?(filter.solr)
        config.add_facet_field solr, **options
        add_colour_option(config, filter.group) if filter.solr == DIGITAL_ASSET_FORMAT_FIELD
      end

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

    # The "With Digital Asset" filter: its facet key (kept from CCS-41, so saved searches and links still work), and its values'
    # labels. A pill or a saved search's name says the filter's name too, as "With Digital Asset: Yes" (.digital_asset_choice).
    DIGITAL_ASSET_FIELD = SearchDefaults::DIGITAL_ASSET_FIELD
    DIGITAL_ASSET_VALUES = { "with" => "Yes", "without" => "No" }.freeze

    # The Colour filter sits under Digital Asset Format Type (docs/colour-and-clean-up.md)
    DIGITAL_ASSET_FORMAT_FIELD = "digital_asset_format_ssim"
    COLOUR_FIELD = "colour_ssim"

    # "Colour": the colour names of the records' images (rake colour:write). Not in the workbook: an addition the owner approved on
    # 2026-11-17 (docs/decisions-2027.md). Like every list filter, it is not drawn while the index has no values for it.
    def self.add_colour_option(config, group)
      config.add_facet_field COLOUR_FIELD, label: I18n.t("colours.filter"), group: group, limit: nil, sort: "count",
        helper_method: :colour_facet_label, include_in_advanced_search: false, **MULTI_SELECT.call(COLOUR_FIELD)
    end

    # Filters whose stored values are codes, shown through a helper (FacetValuesHelper)
    VALUE_HELPERS = { "dam_access_tier_ssi" => :access_tier_facet_label }.freeze

    # FILM COPY (as CCS-2026 #221): multi-select. The values are alternatives (InclusiveFilterField), the filter query is tagged
    # with the field, and Solr leaves that tag out when it counts the facet's own values, so a chosen collection keeps the others listed.
    MULTI_SELECT = ->(field) { { filter_class: InclusiveFilterField, tag: field, ex: field } }

    # "With Digital Asset" (the workbook's filter after Digital Asset Format Type, first asked for by CCS-41): Yes shows the records
    # with an asset a visitor may see (has_digital_asset_bsi), No the rest. filter: its DataModel::Filter (name and section).
    def self.add_digital_asset_option(config, filter)
      config.add_facet_field DIGITAL_ASSET_FIELD, label: filter.name, group: filter.group, filter_class: DigitalAssetFilterField, query: {
        with: { label: DIGITAL_ASSET_VALUES["with"], fq: "#{filter.solr}:true" },
        without: { label: DIGITAL_ASSET_VALUES["without"], fq: "-#{filter.solr}:true" }
      }
    end

    # "With Digital Asset: Yes": a choice of the filter named in full, for the places that show a value without its filter
    # (a saved search's name, the "Why am I seeing these results?" panel, the default filter's notices). nil for another value.
    def self.digital_asset_choice(value)
      label = DIGITAL_ASSET_VALUES[value.to_s]
      "#{DataModel.filters.find { |filter| filter.key == DIGITAL_ASSET_FIELD }&.name}: #{label}" if label
    end

    # The "Open licence (public domain)" switch (FreeReuse): not in the workbook; it sits under With Digital Asset. A switch, not a
    # list of values, on the results page (NexusCcs::FreeReuseSwitchComponent) and on Advanced search (FreeReuseAdvancedComponent).
    def self.add_free_reuse_option(config)
      config.add_facet_field FreeReuse::FIELD, label: I18n.t("nexus_ccs.free_reuse.facet"), group: "media_type", query: FreeReuse.query_config,
        component: NexusCcs::FreeReuseSwitchComponent, advanced_search_component: NexusCcs::FreeReuseAdvancedComponent
    end
  end
end
