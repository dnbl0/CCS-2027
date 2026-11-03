require "test_helper"

# The workbooks define the data model (DataModel); these tests keep the Rails app faithful to it.
class DataModelTest < ActiveSupport::TestCase
  def config = CatalogController.blacklight_config

  def indexer_source
    Dir[Rails.root.join("app/indexers/collections/*.rb")].sum("") { |file| File.read(file) }
  end

  test "every workbook field and filter is mapped, and nothing else is" do
    assert_equal (1..13).to_a + (15..29).to_a, DataModel::MAPPING["fields"].keys.sort
    assert_equal (1..23).to_a, DataModel::MAPPING["filters"].keys.sort
    assert_equal DataModel::FIELD_LABELS.map { |row| row["seq"] }.sort, DataModel::MAPPING["fields"].keys.sort
    assert_equal DataModel::FILTER_ROWS.map { |row| row["seq"] }.sort, DataModel::MAPPING["filters"].keys.sort
  end

  test "each field and filter has a Solr field or a stated reason it has none, never both" do
    (DataModel.fields + DataModel.filters).each do |item|
      assert_not_equal item.solr.present?, item.gap.present?, "#{item.try(:label) || item.name}: needs exactly one of solr or gap"
    end
  end

  test "every Solr field the model uses is written by an indexer" do
    (DataModel.fields + DataModel.filters).select(&:available?).each do |item|
      assert_includes indexer_source, %("#{item.solr}"), "#{item.solr} is not written by any indexer"
    end
  end

  # CCS-41 asks for a with/without digital assets option, which is not in the workbook's filter list.
  JIRA_ADDITIONS = %w[has_digital_asset free_reuse].freeze # free_reuse: the open-licence switch (FreeReuse), not a workbook filter either

  test "facets are every workbook filter, in the order of the sheet's # column, with its names, sections and types" do
    expected = DataModel.filters
    actual = config.facet_fields.values.reject { |facet| JIRA_ADDITIONS.include?(facet.key) }

    assert_equal (1..23).to_a, expected.map(&:seq)
    assert_equal expected.map(&:key), actual.map(&:key)
    assert_equal expected.map(&:name), actual.map(&:label)
    assert_equal expected.map(&:group), actual.map(&:group)
    expected.zip(actual).each do |filter, facet|
      assert_equal filter.type == :year, facet.range.present?, "#{filter.name}: only year selectors are range facets"
      assert_equal NexusCcs::AdvancedYearRangeComponent, facet.advanced_search_component, filter.name if filter.type == :year
    end
  end

  test "a filter with no data yet is still shown, with a note, on the results and in Advanced search, and is never asked of Solr" do
    gaps = DataModel.filter_gaps
    assert_includes gaps.map(&:name), "Film & Gaming Classification"
    advanced_request = config.advanced_search.form_solr_parameters

    gaps.each do |filter|
      facet = config.facet_fields.fetch(filter.key)
      assert_equal NexusCcs::PendingFacetComponent, facet.component, filter.name
      assert_equal NexusCcs::PendingFacetComponent, facet.advanced_search_component, filter.name
      assert_not_equal false, facet.include_in_advanced_search, filter.name
      assert_equal false, facet.include_in_request, filter.name
      assert_not_includes advanced_request["facet.field"], filter.key
      assert_not advanced_request.key?("f.#{filter.key}.facet.limit"), filter.name
    end
  end

  test "the facet beyond the workbook: CCS-41's digital asset option, above Digital Asset Format Type" do
    extra = config.facet_fields["has_digital_asset"]

    assert_equal %w[with without], extra.query.keys.map(&:to_s)
    assert_equal "media_type", extra.group

    order = config.facet_fields.keys
    assert_equal %w[free_reuse digital_asset_format_ssim], order[order.index("has_digital_asset") + 1, 2] # the open-licence switch sits under it
  end

  test "Creator role is a workbook filter, between Creator Name and the birth date" do
    order = config.facet_fields.keys
    assert_equal %w[creator_ssim creator_role_ssim creator_birth_isim], order[order.index("creator_ssim"), 3]
  end

  test "filter sections appear in the workbook's order with titles" do
    assert_equal %w[collection_details creator object subject_topic copyright_advisory access media_type], config.facet_group_names
    config.facet_group_names.each do |group|
      assert I18n.exists?("blacklight.search.facets-#{group}.title"), "no title for the #{group} filter section"
    end
  end

  test "record fields use the workbook's labels in its order, without repeating the title" do
    expected = DataModel.fields.select(&:available?).reject { |field| field.seq == 1 }

    assert_equal expected.map(&:solr), config.show_fields.values.map(&:field)
    assert_equal expected.map(&:label), config.show_fields.values.map(&:label)
  end

  test "the results list shows the fields the mapping marks for it" do
    expected = DataModel.fields.select { |field| field.available? && field.index }

    assert_equal expected.map(&:solr), config.index_fields.values.map(&:field)
  end

  test "fields the data cannot carry yet are not shown, and DAM fields are all gaps" do
    shown = config.show_fields.values.map(&:label)

    DataModel.field_gaps.each { |field| assert_not_includes shown, field.label }
    assert_equal [ 26, 27, 28, 29 ], DataModel.fields.select { |field| field.source == "DAM" }.map(&:seq)
    assert DataModel.fields.select { |field| field.source == "DAM" }.none?(&:available?)
  end

  test "access conditions stay out of the record fields" do
    assert_not_includes config.show_fields.values.map(&:field), "access_condition_ssi"
    assert_not_includes config.show_fields.values.map(&:field), "restrictions_tsi"
  end
end
