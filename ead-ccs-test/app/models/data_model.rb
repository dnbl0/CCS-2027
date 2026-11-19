# The CCS data model: the display fields and filters defined by the two project workbooks
# (../CCS Field labels and filters - Project Owners to Review.xlsx at the repo root, data/CCS-data-inventory.xlsx), extracted to
# config/data_model/*.json by script/extract_data_model.py, plus config/data_model/solr_mapping.yml
# which says which Solr field carries each one (or why none does yet).
#
# Field seq is the workbook's FINAL SEQUENCE ORDER. CatalogController builds its fields, facets and facet groups from this, so the workbooks stay
# the source of truth for labels, order, sections and filter types.
class DataModel
  FIELD_LABELS = JSON.parse(Rails.root.join("config/data_model/field_labels.json").read).freeze
  FILTER_ROWS = JSON.parse(Rails.root.join("config/data_model/filters.json").read).freeze
  MAPPING = YAML.safe_load_file(Rails.root.join("config/data_model/solr_mapping.yml")).freeze

  # Labels the sheet's display rules set apart from its label cell: Measurements (11) carries a note in that cell ("... previosly
  # mentioned as Dimensions") and its rule 2 says "CCS label will be 'Measurements'".
  DISPLAY_LABELS = { 11 => "Measurements" }.freeze

  Field = Data.define(:seq, :label, :source, :solr, :index, :gap) do
    def available? = solr.present?

    # The label a page shows
    def display_label = DISPLAY_LABELS.fetch(seq, label)
  end

  # `type` is :checkbox, :browse (browse and search within the filter), :year (year selector) or :other.
  Filter = Data.define(:seq, :section, :name, :type, :solr, :gap, :facet) do
    def available? = solr.present?

    # The facet key: the mapping's own (`facet:`, a query facet such as has_digital_asset), else the Solr field, or for a filter with
    # no data yet a stand-in made from its name.
    def key = facet || solr || "pending_#{name.parameterize(separator: "_")}"

    # A form usable as a facet group id and locale key: "Subject / Topic" becomes "subject_topic".
    def group = section.parameterize(separator: "_")
  end

  TYPES = { "Checkbox" => :checkbox, "Browse + Search within this filter" => :browse, "Date selector (Year)" => :year }.freeze

  class << self
    # The workbook's display fields in sequence order.
    def fields
      @fields ||= FIELD_LABELS.sort_by { |row| row["seq"] }.map do |row|
        mapping = MAPPING.fetch("fields").fetch(row["seq"])
        Field.new(seq: row["seq"], label: row["label"], source: row["source"], solr: mapping["solr"],
          index: mapping["index"] == true, gap: mapping["gap"])
      end
    end

    # The workbook's filters, ordered by the sheet's # column.
    def filters
      @filters ||= FILTER_ROWS.sort_by { |row| row["seq"] }.map do |row|
        mapping = MAPPING.fetch("filters").fetch(row["seq"])
        Filter.new(seq: row["seq"], section: row["section"], name: row["name"], type: TYPES.fetch(row["type"], :other),
          solr: mapping["solr"], gap: mapping["gap"], facet: mapping["facet"])
      end
    end

    # Filter sections in sheet order, each with its filters.
    def sections = filters.group_by(&:section)

    def field_gaps = fields.reject(&:available?)
    def filter_gaps = filters.reject(&:available?)
  end
end
