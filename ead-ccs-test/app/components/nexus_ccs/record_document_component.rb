# frozen_string_literal: true

module NexusCcs
  # A record's page body: one header block (RecordHeaderComponent), then two columns from 1200px (the media or one plain sentence
  # about its absence, with the details under it; and a plain column of actions and Key facts) and one column below. After the
  # Key facts come Object details, Copyright and use, About this record. Registered as the show page's document_component; the
  # breadcrumb above it is HeaderComponent's. The fields, their labels and their order come from the workbook (config.show_fields,
  # see DataModel); the Copyright and use section gathers the rights fields.
  class RecordDocumentComponent < Blacklight::DocumentComponent
    include RecordDebias # de-bias notices: the finds in the displayed text, and a value with them marked

    # Shown in the Copyright card, so not repeated in the details list
    COPYRIGHT_FIELDS = %w[rights_ssim credit_line_tsim].freeze
    LINK_FIELDS = %w[collection_ssim].freeze

    Row = Struct.new(:label, :values, :field, :copy, keyword_init: true)

    def heading
      Array(document["title_tsim"]).first.presence || @presenter.heading
    end

    def media?
      Array(document["digital_asset_large_paths_ssim"]).any?
    end

    # Whether the record has a digital asset to draw (DigitalAssetsComponent), whatever the policy lets this visitor see; if not, the
    # page says so in one plain sentence (NoImageComponent)
    def assets?
      Array(document["digital_asset_large_paths_ssim"]).any? || Array(document["digital_media_ssim"]).any?
    end

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
    BROWSE_KINDS = { "production_place_ssim" => "places", "subject_ssim" => "subjects", "creator_display_ssim" => "makers" }.freeze

    def browse_path(row, value)
      kind = BROWSE_KINDS[row.field] or return
      # creator_display_ssim is "Name (born - died) Role": the page is for the name, which is the record's creator_ssim value it starts with
      value = Array(document["creator_ssim"]).select { |name| value.start_with?(name) }.max_by(&:length) if kind == "makers"
      Browse.path_for(kind, value) if value
    end

    def value_path(row, value)
      helpers.search_action_path(filter_query(row.field, value))
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
  end
end
