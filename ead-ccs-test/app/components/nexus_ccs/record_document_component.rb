# frozen_string_literal: true

module NexusCcs
  # A record's page body in the showcase layout (20 Nov 2026, after the museums' object pages, light theme): the image centred on a
  # full-width band, then a white card over its lower edge with the record (title, object type and date, the maker and place rows,
  # the description, Object details, About this record) and, beside it from 1024px, the actions and Use and access. You may also like
  # and More from the collections follow (catalog/show). Registered as the show page's document_component; the breadcrumb above it is
  # HeaderComponent's. The fields, their labels and their order come from the workbook (DataModel: the sheet "CCS Field Labels");
  # the Use and access panel gathers the rights and access information.
  class RecordDocumentComponent < Blacklight::DocumentComponent
    include RecordDebias # de-bias notices: the finds in the displayed text, and a value with them marked

    # Values that open the search filtered to them (Blacklight's link_to_facet idea), so a visitor can step sideways to more of the same.
    # Creator, place and subject open their browse page instead (BROWSE_KINDS), and the filter when the value has none. Free text
    # (description, credit line, dates) is never a link.
    # Read when the core has them, though the workbook does not list them: shown as rows of terms beside the workbook's date and place
    EXTRA_TERM_FIELDS = { "date_era_ssim" => 3.5, "region_ssim" => 7.5 }.freeze
    LINK_FIELDS = (%w[collection_ssim named_collection_ssim object_type_ssim classification_ssim material_ssim] + EXTRA_TERM_FIELDS.keys).freeze
    # Shown as filters where a browse page does not take them: the field each display field filters on
    FALLBACK_FILTER_FIELDS = { "subject_ssim" => "subject_ssim", "creator_display_ssim" => "creator_ssim" }.freeze
    # seq: the workbook's FINAL SEQUENCE ORDER (DataModel); join: how the sheet joins several values into one line
    Row = Struct.new(:label, :values, :field, :seq, :join, :copy, keyword_init: true)

    def heading
      Array(document["title_tsim"]).first.presence || @presenter.heading
    end

    def media?
      Array(document["digital_asset_large_paths_ssim"]).any?
    end

    # Whether the record has a digital asset to draw (DigitalAssetsComponent), whatever the policy lets this visitor see; if not, the
    # page says so in one plain sentence (NoImageComponent)
    def assets? = RecordMedia.assets?(document)

    # Fields that name a collection: their links open all of it, as the header's Search collections menu does
    # (BrowseMenu, docs/adr/0004). Any other detail keeps the search's default.
    WHOLE_SET_FIELDS = [ BrowseMenu::COLLECTION_FIELD, "named_collection_ssim" ].freeze

    def filter_query(field, value)
      WHOLE_SET_FIELDS.include?(field) ? BrowseMenu.query(field, value) : { f: { field => [ value ] } }
    end

    # "Grainger Museum Collection, accession number 00.0001, UoM ID emu-umc-400329" (CCS-22)
    def identifier = CollectionIdentifier.new(document).to_s

    def uom_id = CollectionIdentifier.uom_id(document.id)

    # The record's permanent address (CCS-22: Copy permalink beside the ID)
    def permalink = helpers.solr_document_url(document)

    def link_to_value?(row) = row.field.in?(LINK_FIELDS)

    # A record's place, subject and creator values link to the browse page for the value (Browse), where one exists
    BROWSE_KINDS = { "production_place_ssim" => "places", "subject_ssim" => "subjects", "creator_display_ssim" => "makers", "creator_ssim" => "makers" }.freeze

    def browse_path(row, value)
      kind = BROWSE_KINDS[row.field] or return
      # creator_display_ssim is "Name (born - died) Role": the page is for the name, which is the record's creator_ssim value it starts with
      value = creator_name(value) if kind == "makers"
      Browse.path_for(kind, value) if value
    end

    def creator_name(display) = Array(document["creator_ssim"]).select { |name| display.start_with?(name) }.max_by(&:length)

    def value_path(row, value)
      helpers.search_action_path(filter_query(row.field, value))
    end

    # Where a value in the details leads: its filtered search, its browse page, or nowhere (free text)
    def value_link(row, value)
      return value_path(row, value) if link_to_value?(row)

      browse_path(row, value) || fallback_filter_path(row, value)
    end

    def fallback_filter_path(row, value)
      field = FALLBACK_FILTER_FIELDS[row.field] or return
      value = creator_name(value) if row.field == "creator_display_ssim"
      helpers.search_action_path(filter_query(field, value)) if value
    end

    # The rights fields (Use and access)
    def credit_line = Array(document["credit_line_tsim"]).first
    def copyright = Array(document["rights_ssim"]).first
    def licence = Array(document["licence_type_ssim"]).first
    def responsible_collection = Array(document["collection_ssim"]).first

    def responsible_collection_query = filter_query(BrowseMenu::COLLECTION_FIELD, responsible_collection)

    # The caption the DAM supplies (the essential information CCS-67 names, with the licence); else one is built from the record
    def dam_caption = Array(document["caption_tsim"]).first.presence

    # "Title. Date. Creator. Material. © Rights. Collection."
    def caption
      parts = [ heading, Array(document["production_date_ssim"]).first, Array(document["creator_ssim"]).first(2).join("; "),
                Array(document["material_ssim"]).first, copyright, responsible_collection ]
      parts.compact_blank.map { |part| part.to_s.sub(/[.\s]+\z/, "") }.join(". ").then { |text| text.present? ? "#{text}." : nil }
    end

    # Whether the record says anything about its rights. Use and access is on every record page (CCS-148); when this is false it says
    # so, rather than saying nothing, so a visitor is never left to think "nothing said" means "no restriction".
    def rights_recorded?
      [ credit_line, copyright, licence ].any?(&:present?)
    end

    def terms_path = "/help#copyright"

    # --- The approved split layout (Figma "Record page · Approved design", 2026-11-19) -------------------------------------------
    # The media on the left (it stays in view on a wide screen), the record's own column on the right: where it is in the visitor's
    # search, the collection, the title, maker, date and medium, the actions, Use and access, the description, Object details (Key
    # facts and the grouped full record), then two folding sections. Related objects, More from the collections and About this record run full width under.

    renders_one :stepper # the search-result stepper and the selection stepper, from catalog/show (they need the controller's search context)

    DESCRIPTION_FIELD = "description_tsim"
    HISTORY_FIELDS = { "source_reference_tsim" => :source_reference }.freeze # the credit line is in Use and access

    # "University Art Collection", linking to the whole collection
    def collection_name = responsible_collection

    def collection_path = collection_name && helpers.search_action_path(responsible_collection_query)

    # [[name, browse path or nil]]: the record's first two makers (not "Unknown"), each linking to the maker's browse page where there is one
    def makers
      maker_names.first(2).map { |name| [ name, Browse.path_for("makers", name) ] }
    end

    def maker_names = Array(document["creator_ssim"]).map(&:to_s).compact_blank.reject { |name| name == RecordCardComponent::UNKNOWN_MAKER }

    def display_date = Array(document["date_display_ssm"]).first.presence || Array(document["production_date_ssim"]).first.presence

    def medium = (Array(document["material_display_ssm"]).first.presence || Array(document["material_ssim"]).first.presence)&.to_s&.upcase_first

    # The description's paragraphs: the first is the lead (larger), the rest sit under it
    def description_paragraphs
      @description_paragraphs ||= Array(document[DESCRIPTION_FIELD]).flat_map { |text| text.to_s.split(/\n\s*\n/) }.map(&:strip).compact_blank
    end

    def lead = description_paragraphs.first
    def description_rest = description_paragraphs.drop(1)

    # --- Object details (CCS-400; the sheet "CCS Field Labels", FINAL SEQUENCE ORDER) ---------------------------------------------
    # Every display field the record has a value for, in the sheet's sequence and under its label; a field with no value has no row
    # ("it will be blank and label also does not appear"). The title and the description are the column's own (above), the credit
    # line and copyright are in Use and access, and the DAM fields (licence type, advisory, terms of use, producer) are the media
    # information (DigitalAssetsComponent). The sheet's
    # display rules: Date (3) joined with "; ", Place (7) with ", ", Classification (17) hyphenated; Creator (4) as "Name (b. - d.)
    # role"; Related Record (25) one line each, marked with its relation (the data carries the parent only); Inscription (12) one
    # line each (the exports carry no inscription type to group them by).
    # The title and description (the column's own), and the credit line and copyright (Use and access, CCS-27)
    OWN_FIELDS = [ 1, 16, 21, 22 ].freeze
    # Stored under another name in part of the index (the local core, harvested records)
    VALUE_FALLBACKS = { "creator_display_ssim" => %w[creator_display_ssm], "source_url_ss" => %w[source_url_ssi] }.freeze
    SOURCE_URL_SEQ = 23
    RELATED_SEQ = 25
    CREATOR_SEQ = 4

    # The key rows under the title, outside Object details: who made it (Creator, 4) and where (Place, 7)
    LEAD_SEQS = [ 4, 7 ].freeze

    def detail_rows
      @detail_rows ||= begin
        rows = DataModel.fields.filter_map do |field|
          next if field.source == "DAM" || OWN_FIELDS.include?(field.seq) || !field.available?

          values = field_values(field)
          Row.new(label: field.display_label, values: values, field: field.solr, seq: field.seq, join: StockRecordFields::JOINS[field.seq]) if values.any?
        end
        rows += EXTRA_TERM_FIELDS.filter_map do |name, seq|
          values = Array(document[name]).map(&:to_s).compact_blank.uniq
          Row.new(label: I18n.t("nexus_ccs.record_page.split.extra.#{name}"), values: values, field: name, seq: seq) if values.any?
        end
        rows.sort_by(&:seq)
      end
    end

    # Object details: the sheet's own fields after the key rows (not the index's era and region, which repeat the date and the place)
    def object_rows = detail_rows.reject { |row| LEAD_SEQS.include?(row.seq) || !row.seq.is_a?(Integer) }


    def lead_rows = detail_rows.select { |row| LEAD_SEQS.include?(row.seq) }

    # --- The record card (after the Van Gogh Museum's object pages) -------------------------------------------------------------
    # The bold line under the title: who made it (with life dates), where (the most specific place) and when
    def maker_line
      creators = (detail_rows.find { |row| row.seq == CREATOR_SEQ }&.values || []).first(2)
      place = Array(document["production_place_ssim"]).map(&:to_s).compact_blank.last
      [ creators.join("; ").presence, place, display_date ].compact_blank.join(", ")
    end

    # The lines under it: the material and measurements; the credit line; the collection and accession number
    def facts_lines
      measurements = Array(document["dimensions_ssm"]).map(&:to_s).compact_blank.join("; ")
      accession = Array(document["accession_number_ssim"]).first.presence
      [ [ medium, measurements.presence ].compact.join(", ").presence,
        credit_line,
        [ collection_name, (I18n.t("nexus_ccs.record_page.card.accession", number: accession) if accession) ].compact.join(", ").presence ].compact
    end

    # "Search in the collection": the record's names and terms, each a link to its search or browse page (as in Object details),
    # when first, era, place, kind, material and subject, then classification, maker and collections; at most 14, no repeats
    SEARCH_ORDER = [ 3.5, 7, 2, 10, 15, 17, 4, 18, 19 ].freeze

    def search_terms
      @search_terms ||= begin
        rows = detail_rows.select { |row| term?(row) && SEARCH_ORDER.include?(row.seq) }.sort_by { |row| SEARCH_ORDER.index(row.seq) }
        terms = rows.flat_map do |row|
          row.values.filter_map do |value|
            label = row.seq == CREATOR_SEQ ? (creator_name(value) || value.sub(/\s*\(.*\z/, "")) : value
            path = value_link(row, value)
            [ label, path ] if path
          end
        end
        terms.uniq(&:first).first(14)
      end
    end


    # The record's source reference ends Object details, after the sheet's fields
    def history_rows
      HISTORY_FIELDS.filter_map do |field, key|
        values = Array(document[field]).map(&:to_s).compact_blank
        Row.new(label: I18n.t("nexus_ccs.record_page.split.history.#{key}"), values: values, field: field, seq: 100) if values.any?
      end
    end

    # What the de-bias notices scan (RecordDebias): the details and the description
    def rows = detail_rows + [ description_row ].compact

    def description_row
      values = Array(document[DESCRIPTION_FIELD]).map(&:to_s).compact_blank
      Row.new(label: I18n.t("nexus_ccs.record_page.split.description_label"), values: values, field: DESCRIPTION_FIELD, seq: 16) if values.any?
    end

    def field_values(field)
      names = [ field.solr ] + VALUE_FALLBACKS.fetch(field.solr, [])
      values = names.lazy.map { |name| Array(document[name]).map(&:to_s).compact_blank }.find(&:any?) || []
      case field.seq
      when CREATOR_SEQ then values.any? ? StockRecordFields::DERIVED[CREATOR_SEQ].call({ "creator_display_ssim" => values }) : maker_names
      when RELATED_SEQ then values.map { |value| I18n.t("nexus_ccs.record_page.split.related_parent", record: value) }
      else values
      end
    end

    def source_url?(row) = row.seq == SOURCE_URL_SEQ

    # The Source URL row's value (CCS-25): the record on its collection's website, behind the leaving-site dialog
    def view_full_record = ViewFullRecordComponent.new(document: document, action: nil)

    # A value shown as a term (an outlined tag that opens its search or browse page): the values that name things
    def term?(row) = link_to_value?(row) || BROWSE_KINDS.key?(row.field) || FALLBACK_FILTER_FIELDS.key?(row.field)

    # --- Use and access (CCS-27, CCS-47, CCS-67, CCS-68, CCS-69, CCS-166) -----------------------------------------------------------
    # One panel under the actions: can the visitor see the image, can they download it, under what licence, the rights items CCS-27
    # lists (accession number, caption, credit line, copyright, terms of use, contact) and the way to ask the collection.

    def media_component = @media_component ||= DigitalAssetsComponent.new(presenter: @presenter)

    # :none (no digital asset), :open, :view_only or :request (AccessPolicy)
    def access_state = assets? ? AccessPolicy.tier(document) : :none

    def sensitive? = assets? && access_state != :request && Sensitivity.sensitive?(document)

    def view_status = I18n.t("nexus_ccs.record_page.use.view.#{access_state}")
    def download_status = I18n.t("nexus_ccs.record_page.use.download.#{access_state}")
    def can_view? = %i[open view_only].include?(access_state)
    def can_download? = access_state == :open

    def use_licence = assets? ? media_component.licence : licence

    # The rights items, [[label, value]], in CCS-27's order (with the licence); caption and terms of use belong to a digital asset
    def rights_items
      [ [ I18n.t("nexus_ccs.record_page.use.accession_number"), Array(document["accession_number_ssim"]).first ],
        [ I18n.t("nexus_ccs.record_page.use.licence"), use_licence ],
        [ I18n.t("nexus_ccs.record_page.use.caption"), (dam_caption || caption if assets?) ],
        [ I18n.t("nexus_ccs.record_page.use.credit_line"), credit_line ],
        [ I18n.t("nexus_ccs.record_page.use.copyright"), copyright ],
        [ I18n.t("nexus_ccs.record_page.use.terms_of_use"), (media_component.terms if assets?) ] ]
        .select { |_label, value| value.present? }.uniq { |_label, value| value.to_s.squish } # a DAM often repeats one statement
    end

    def request_to_view_path = AccessPolicy.request_path(document)
  end
end
