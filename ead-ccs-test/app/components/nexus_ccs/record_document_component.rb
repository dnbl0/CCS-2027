# frozen_string_literal: true

module NexusCcs
  # A record's page body in the approved split layout (Figma "Record page · Approved design", 2026-11-19): the media on the left
  # and the record's own column on the right from 1024px (one column below, media first), then Related objects, More from the
  # collections and About this record at full width. Registered as the show page's document_component; the breadcrumb above it is
  # HeaderComponent's. The fields, their labels and their order come from the workbook (config.show_fields, see DataModel); the
  # Copyright and reuse section gathers the rights fields.
  class RecordDocumentComponent < Blacklight::DocumentComponent
    include RecordDebias # de-bias notices: the finds in the displayed text, and a value with them marked

    # Shown in the Copyright card, so not repeated in the details list
    COPYRIGHT_FIELDS = %w[rights_ssim credit_line_tsim].freeze
    # Values that open the search filtered to them (Blacklight's link_to_facet idea), so a visitor can step sideways to more of the same.
    # Creator, place and subject open their browse page instead (BROWSE_KINDS), and the filter when the value has none. Free text
    # (description, credit line, dates) is never a link.
    # Read when the core has them, though the workbook does not list them: shown as their own rows of terms after its fields
    EXTRA_TERM_FIELDS = %w[date_era_ssim region_ssim].freeze
    LINK_FIELDS = (%w[collection_ssim named_collection_ssim object_type_ssim classification_ssim material_ssim] + EXTRA_TERM_FIELDS).freeze
    # Shown as filters where a browse page does not take them: the field each display field filters on
    FALLBACK_FILTER_FIELDS = { "subject_ssim" => "subject_ssim", "creator_display_ssim" => "creator_ssim" }.freeze
    Row = Struct.new(:label, :values, :field, :copy, keyword_init: true)

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

    # The details list: every workbook field the record has a value for, except the ones shown elsewhere on the page: the Key facts
    # (KeyFactsComponent), the Copyright and use section, and the header (the title and the Collection ID, which holds the UoM ID)
    def rows
      @rows ||= @presenter.configuration.show_fields.each_value.filter_map do |config|
        name = config.field
        next if COPYRIGHT_FIELDS.include?(name) || KeyFactsComponent.fields.include?(name)

        values = Array(document[name]).map(&:to_s).compact_blank
        Row.new(label: config.label, values: values, field: name) if values.any?
      end
    end

    # "Grainger Museum Collection, accession number 00.0001, UoM ID emu-umc-400329" (CCS-22)
    def identifier = CollectionIdentifier.new(document).to_s

    def uom_id = CollectionIdentifier.uom_id(document.id)

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

    # The "Copyright" card
    def credit_line = Array(document["credit_line_tsim"]).first
    def copyright = Array(document["rights_ssim"]).first
    def licence = Array(document["licence_type_ssim"]).first
    def responsible_collection = Array(document["collection_ssim"]).first

    def responsible_collection_query = filter_query(BrowseMenu::COLLECTION_FIELD, responsible_collection)

    # The caption the DAM supplies, shown in Copyright and use only when there is one: the page's own title, date, creator and
    # rights are already above it, so a caption built from them would add nothing
    def dam_caption = Array(document["caption_tsim"]).first.presence

    # "Title. Date. Creator. Material. © Rights. Collection."
    def caption
      parts = [ heading, Array(document["production_date_ssim"]).first, Array(document["creator_ssim"]).first(2).join("; "),
                Array(document["material_ssim"]).first, copyright, responsible_collection ]
      parts.compact_blank.map { |part| part.to_s.sub(/[.\s]+\z/, "") }.join(". ").then { |text| text.present? ? "#{text}." : nil }
    end

    # Whether the record says anything about its rights. The card is on every record page (CCS-148); when this is false it says so,
    # rather than saying nothing, so a visitor is never left to think "no card" means "no restriction".
    def rights_recorded?
      [ credit_line, copyright, licence ].any?(&:present?)
    end

    def terms_path = "/help#copyright"

    # --- The approved split layout (Figma "Record page · Approved design", 2026-11-19) -------------------------------------------
    # The media on the left (it stays in view on a wide screen), the record's own column on the right: where it is in the visitor's
    # search, the collection, the title, maker, date and medium, the actions, "Where it is", the description, Object details (label
    # above value), then four folding sections. Related objects, More from the collections and About this record run full width under.

    renders_one :stepper # the search-result stepper and the selection stepper, from catalog/show (they need the controller's search context)

    DESCRIPTION_FIELD = "description_tsim"
    # Shown in the column's header lines, so not repeated as rows: the title, and the description (the lead and the text under it)
    HEADER_FIELDS = %w[title_tsim description_tsim].freeze
    HISTORY_FIELDS = { "credit_line_tsim" => :credit_line, "source_reference_tsim" => :source_reference }.freeze

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

    # Object details: every workbook field the record has a value for, in the workbook's order, except the header's and the rights
    # fields (in Copyright and reuse); the UoM ID follows them, with a Copy button
    def detail_rows
      @detail_rows ||= begin
        rows = @presenter.configuration.show_fields.each_value.filter_map do |config|
          name = config.field
          next if HEADER_FIELDS.include?(name) || COPYRIGHT_FIELDS.include?(name)

          values = Array(document[name]).map(&:to_s).compact_blank
          Row.new(label: config.label, values: values, field: name) if values.any?
        end
        rows += [ maker_row ].compact if rows.none? { |row| row.field == "creator_display_ssim" }
        rows + EXTRA_TERM_FIELDS.filter_map do |name|
          values = Array(document[name]).map(&:to_s).compact_blank.uniq
          Row.new(label: t("nexus_ccs.record_page.split.extra.#{name}"), values: values, field: name) if values.any?
        end
      end
    end

    # The Maker row from the record's plain creator names, for a record without the display form (name, dates and role) the
    # workbook's field holds; each name opens the maker's browse page
    def maker_row
      Row.new(label: t("nexus_ccs.record_page.split.extra.creator_ssim"), values: maker_names, field: "creator_ssim") if maker_names.any?
    end

    # A value shown as a term (an outlined tag that opens its search or browse page): the values that name things
    def term?(row) = link_to_value?(row) || BROWSE_KINDS.key?(row.field) || FALLBACK_FILTER_FIELDS.key?(row.field)

    # The folding sections' contents
    def media_details = assets? ? DigitalAssetsComponent.new(presenter: @presenter).metadata : []

    def history
      HISTORY_FIELDS.filter_map do |field, key|
        value = Array(document[field]).first.presence
        [ t("nexus_ccs.record_page.split.history.#{key}"), value ] if value
      end
    end

    def where_body
      key = collection_name ? "body" : "body_no_collection"
      t("nexus_ccs.record_page.split.where.#{key}", collection: collection_name)
    end

    def request_to_view_path = AccessPolicy.request_path(document)
  end
end
