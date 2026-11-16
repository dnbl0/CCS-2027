# frozen_string_literal: true

module CatalogConfig
  # The search field menu (all fields, title, creator, subject, description). The qf/pf values are in the /select handler of solr/conf/solrconfig.xml.
  module SearchFields
    def self.apply(config)
      # ================================================================
      # Search fields
      # The qf/pf values are defined in the /select handler in solr/conf/solrconfig.xml
      # ================================================================
      config.add_search_field "all_fields", label: "All Fields"

      config.add_search_field("title") do |field|
        field.solr_parameters = {
          'spellcheck.dictionary': "title",
          qf: "${title_qf}",
          pf: "${title_pf}"
        }
      end

      config.add_search_field("creator") do |field|
        # No spellcheck.dictionary override: the "author" dictionary is built from
        # author_spell, which is fed by author_tsim (not populated)
        field.solr_parameters = {
          qf: "${creator_qf}",
          pf: "${creator_pf}"
        }
      end

      config.add_search_field("subject") do |field|
        field.solr_parameters = {
          'spellcheck.dictionary': "subject",
          qf: "${subject_qf}",
          pf: "${subject_pf}"
        }
      end

      # Full text (CCS-36): the text inside PDFs. Offered only when the core has the field (PdfTextIndex); not in the advanced form.
      config.add_search_field("full_text") do |field|
        field.label = "Full text (PDF)"
        field.if = ->(_context, _field) { PdfTextIndex.available? }
        field.include_in_advanced_search = false
        field.solr_parameters = { qf: "${pdf_qf}", pf: "${pdf_pf}" }
      end

      # Vernon records only (the EMu export has no description column)
      config.add_search_field("description") do |field|
        field.solr_parameters = {
          qf: "description_tsim",
          pf: "description_tsim"
        }
      end
    end
  end
end
