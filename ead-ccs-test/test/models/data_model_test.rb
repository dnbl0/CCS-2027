require "test_helper"

# The workbooks define the data model (DataModel); these tests keep the Rails app faithful to it.
class DataModelTest < ActiveSupport::TestCase
  def config = CatalogController.blacklight_config

  def indexer_source
    Dir[Rails.root.join("app/indexers/collections/*.rb")].sum("") { |file| File.read(file) }
  end

  test "every workbook field and filter is mapped, and nothing else is" do
    assert_equal (1..13).to_a + (15..29).to_a, DataModel::MAPPING["fields"].keys.sort
    assert_equal (1..24).to_a, DataModel::MAPPING["filters"].keys.sort
    assert_equal DataModel::FIELD_LABELS.map { |row| row["seq"] }.sort, DataModel::MAPPING["fields"].keys.sort
    assert_equal DataModel::FILTER_ROWS.map { |row| row["seq"] }.sort, DataModel::MAPPING["filters"].keys.sort
  end

  test "each field and filter has a Solr field or a stated reason it has none, never both" do
    (DataModel.fields + DataModel.filters).each do |item|
      assert_not_equal item.solr.present?, item.gap.present?, "#{item.try(:label) || item.name}: needs exactly one of solr or gap"
    end
  end

  # Fields this app's indexers do not write: the dev team's ingest fills them in the shared index (seen 2026-11-17), so a core
  # built only by `collections:index` lacks them and their filters show no values there
  DEV_TEAM_INGEST = %w[nationality_ssim date_era_ssim region_ssim subject_agent_ssim digital_asset_advisory_classification_ssim
                       object_access_condition_ssim dimensions_ssm inscription_tsim source_url_ss].freeze

  test "every Solr field the model uses is written by an indexer, the DAM sync, or (listed) the dev team's ingest" do
    dam_writer = Rails.root.join("app/models/dam/solr_writer.rb").read
    (DataModel.fields + DataModel.filters).select(&:available?).each do |item|
      next if DEV_TEAM_INGEST.include?(item.solr)

      assert indexer_source.include?(%("#{item.solr}")) || dam_writer.include?(%("#{item.solr}")),
             "#{item.solr} is not written by any indexer or the DAM sync"
    end
  end

  # The open-licence switch (FreeReuse) is not a workbook filter. (CCS-41's has_digital_asset is now the workbook's "With Digital Asset".)
  JIRA_ADDITIONS = %w[free_reuse place_hierarchy_ssim colour_ssim].freeze # place_hierarchy_ssim: the Place filter (docs/time-and-place.md); colour_ssim: the Colour filter the owner approved on 2026-11-17 (docs/decisions-2027.md)

  test "facets are every workbook filter, in the order of the sheet's # column, with its names, sections and types" do
    expected = DataModel.filters
    actual = config.facet_fields.values.reject { |facet| JIRA_ADDITIONS.include?(facet.key) }

    assert_equal (1..24).to_a, expected.map(&:seq)
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
    assert_equal [ "Language", "Subject Event" ], gaps.map(&:name)
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

  test "With Digital Asset (the project owners' row after #23, CCS-41's filter): Yes / No, after Digital Asset Format Type" do
    filter = DataModel.filters.last
    assert_equal [ 24, "Media type", "With Digital Asset", "has_digital_asset", "has_digital_asset_bsi" ], [ filter.seq, filter.section, filter.name, filter.key, filter.solr ]

    facet = config.facet_fields["has_digital_asset"]
    assert_equal "With Digital Asset", facet.label
    assert_equal({ "with" => "Yes", "without" => "No" }, facet.query.to_h { |key, option| [ key.to_s, option[:label] ] })
    assert_equal [ "has_digital_asset_bsi:true", "-has_digital_asset_bsi:true" ], facet.query.values.map { |option| option[:fq] }
    assert_equal "media_type", facet.group

    order = config.facet_fields.keys
    assert_equal %w[digital_asset_format_ssim colour_ssim has_digital_asset free_reuse], order.last(4) # the open-licence switch sits under it
  end

  test "a filter's choice is named in full where its value is shown alone" do
    assert_equal "With Digital Asset: Yes", CatalogConfig::Facets.digital_asset_choice("with")
    assert_equal "With Digital Asset: No", CatalogConfig::Facets.digital_asset_choice("without")
    assert_nil CatalogConfig::Facets.digital_asset_choice("other")
  end

  test "the Place filter is an addition straight after the workbook's Region, out of Advanced search" do
    order = config.facet_fields.keys
    assert_equal "place_hierarchy_ssim", order[order.index("region_ssim") + 1]
    facet = config.facet_fields["place_hierarchy_ssim"]
    assert_equal config.facet_fields["region_ssim"].group, facet.group
    assert_equal NexusCcs::PlaceHierarchyFacetComponent, facet.component
    assert_equal false, facet.include_in_advanced_search
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
    assert_equal expected.map(&:display_label), config.show_fields.values.map(&:label)
    assert_equal "Measurements", DataModel.fields.find { |field| field.seq == 11 }.display_label # the sheet's display rule 2
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
