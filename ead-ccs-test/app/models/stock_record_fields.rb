# frozen_string_literal: true

# The show fields of the stock record page (StockCatalogController): one row for every field of the "CCS Field Labels"
# sheet (CCS Field labels and filters.xlsx at the repo root, through DataModel: its final sequence order, label and order)
# that the record has a value for, plus the Copyright card's caption. The sheet's DAM fields (Licence Type, Advisory, Terms
# of Use, Producer) are the media metadata: they are shown in the media viewer's modal only (media_keys), not in the details. A field with no value has no row (the sheet: "it will be blank and
# label also does not appear"). Stock page only: the site's own record page does not use this.
module StockRecordFields
  # Numbers are the sheet's FINAL SEQUENCE ORDER (DataModel's seq).
  # How the sheet says several values are joined into one line (Blacklight's separator_options): Date (3) separated
  # with "; " as its examples show, Place (7) "with a comma", Classification (17) hyphenated, "one line of text".
  # Other fields list each value on its own line, Blacklight's default (Related Record (25) says so too).
  JOINS = { 3 => "; ", 7 => ", ", 17 => " - " }.freeze

  # Classification (17) and Subject (15): "preferred" as links that search for records with that value.
  LINKS = [ 17, 15 ].freeze

  # Copyright (22): the licence, as a badge with its icon (Europeana's licence label), above the rights note.
  RIGHTS = 22

  # Fields the indexer carries under a name the data model's mapping does not give them (a DAM field in the sheet,
  # though the licence is derived from the rights note, and the producer is read if an export ever has it).
  SOLR_FIELDS = { 26 => "licence_type_ssim", 29 => "producer_ssim" }.freeze

  # The sheet's label cell for Measurements (11) carries a note ("... previosly mentioned as Dimensions"); its display
  # rule 2 says "CCS label will be 'Measurements'".
  LABELS = { 11 => "Measurements" }.freeze

  # Values the sheet or the site's record page derive rather than read from one Solr field.
  DERIVED = {
    # Creator (4): a person is "Full name (b. <born> - d. <died>) role". The exports have no person/organisation flag
    # and no nationality, so only a name in EMu's person form ("Family, Given") is given the sheet's "b."/"d." form;
    # an organisation's "(estab. - closed)" needs a flag the data lacks, and so keeps its plain "(from - to)".
    4 => lambda { |document|
      Array(document["creator_display_ssim"]).map do |creator|
        creator.include?(",") ? creator.sub(/\(([^()]+?) – ([^()]+?)\)/, '(b. \\1 - d. \\2)') : creator
      end
    },
    # Related Record (25): "each line will be identified with a relation type"; the data carries the parent only.
    25 => ->(document) { Array(document["parent_record_ssi"]).map { |value| "Parent - #{value}" } },
    # Advisory (27): the site's own wording, which every record with digital assets carries (Media metadata panel).
    27 => ->(document) { digital_assets?(document) ? [ NexusCcs::DigitalAssetsComponent::ADVISORY ] : [] },
    # Terms of Use (28): the rights note without the licence in brackets that starts it (as the Media metadata panel).
    28 => lambda { |document|
      note = Array(document["rights_ssim"]).first.to_s.sub(/\A\s*\[[^\]]*\]\s*/, "").strip
      digital_assets?(document) && note.present? ? [ note ] : []
    }
  }.freeze

  class << self
    def apply(config)
      # Link targets of Classification and Subject: Blacklight's link_to_facet needs a facet field; these are not shown
      # (the record page has no facet sidebar), they send the link to the real catalog's filter of the same name.
      config.add_facet_field "classification_ssim", label: "Classification", show: false
      config.add_facet_field "subject_ssim", label: "Subject", show: false

      DataModel.fields.each do |field|
        values = values_for(field)

        config.add_show_field key_for(field), **value_options(field, values)
      end

      # The Copyright card's caption (site record page): "Title. Date. Creator. Material. © Rights. Collection."
      config.add_show_field "caption", label: "Caption", values: ->(_config, document, _context) { caption(document) },
        if: ->(_context, _config, document) { caption(document).any? }
    end

    # The show field keys of the media metadata (the sheet's DAM fields): the media viewer's modal shows these, the details list does not.
    def media_keys = DataModel.fields.select { |field| field.source == "DAM" }.map { |field| key_for(field) }

    # Each rights note under the record's licence badge (none when the record has no licence).
    def rights_with_badge(notes, document, context)
      licence = Array(document["licence_type_ssim"]).first
      badge = context.render(StockLicenceBadgeComponent.new(licence: licence))
      notes.map { |note| context.safe_join([ (context.tag.p(badge, class: "mb-2") if badge.present?), note ].compact) }
    end

    def digital_assets?(document) = RecordMedia.assets?(document)

    def caption(document)
      first = ->(name) { Array(document[name]).first }
      parts = [ first.("title_tsim"), first.("production_date_ssim"), Array(document["creator_ssim"]).first(2).join("; "),
                first.("material_ssim"), first.("rights_ssim"), first.("collection_ssim") ]
      text = parts.compact_blank.map { |part| part.to_s.sub(/[.\s]+\z/, "") }.join(". ")
      text.present? ? [ "#{text}." ] : []
    end

    private

    def key_for(field)
      solr = SOLR_FIELDS.fetch(field.seq, field.solr)
      return solr if solr
      DERIVED.key?(field.seq) ? "gap_#{field.seq}_derived" : "gap_#{field.seq}"
    end

    def label_for(field) = LABELS.fetch(field.seq, field.label)

    # document => [values] for a field: derived by the sheet's rule, or read from its Solr field
    def values_for(field)
      solr = SOLR_FIELDS.fetch(field.seq, field.solr)
      DERIVED[field.seq] || ->(document) { solr ? Array(document[solr]).map(&:to_s).compact_blank : [] }
    end

    def value_options(field, values)
      options = { label: label_for(field), values: ->(_config, document, _context) { values.call(document) },
                  if: ->(_context, _config, document) { values.call(document).any? } }
      options[:values] = ->(_config, document, context) { rights_with_badge(values.call(document), document, context) } if field.seq == RIGHTS
      options[:link_to_facet] = true if LINKS.include?(field.seq)
      join = JOINS[field.seq]
      options[:separator_options] = { words_connector: join, two_words_connector: join, last_word_connector: join } if join
      options
    end
  end
end
