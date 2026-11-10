# frozen_string_literal: true

module NexusCcs
  # The few facts a visitor looks for first, as a description list at the top of the record page's side column: date, materials,
  # classification, subject, collection and credit line. A fact the record does not have is left out; a record with none renders
  # nothing. Object details (RecordDocumentComponent) lists the rest and does not repeat these.
  class KeyFactsComponent < ViewComponent::Base
    FIELDS = [
      [ :date, "production_date_ssim" ],
      [ :materials, "material_ssim" ],
      [ :classification, "classification_ssim" ],
      [ :subject, "subject_ssim" ],
      [ :collection, "collection_ssim" ],
      [ :credit_line, "credit_line_tsim" ]
    ].freeze
    MAX_VALUES = 3

    Fact = Struct.new(:key, :label, :values, :field)

    # Fields shown here, so the details list leaves them out
    def self.fields = FIELDS.map(&:last)

    def initialize(document:)
      @document = document
    end

    def facts
      @facts ||= FIELDS.filter_map do |key, field|
        values = Array(@document[field]).map(&:to_s).compact_blank.first(MAX_VALUES)
        Fact.new(key, t("nexus_ccs.record_page.key_facts.#{key}"), values, field) if values.any?
      end
    end

    def render? = facts.any?

    # The collection links to the whole of it, as the header's Search collections menu does
    def link_path(fact, value)
      return unless fact.field == "collection_ssim"

      helpers.search_action_path(BrowseMenu.query(BrowseMenu::COLLECTION_FIELD, value))
    end
  end
end
