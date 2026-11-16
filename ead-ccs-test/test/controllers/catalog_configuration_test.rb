require "test_helper"

# Out-of-the-box Blacklight features and plugins, checked as configuration so no Solr is needed.
class CatalogConfigurationTest < ActiveSupport::TestCase
  def config = CatalogController.blacklight_config

  test "result views: list plus the blacklight-gallery mosaic (no grid, no slideshow)" do
    assert_equal %i[list masonry], config.view.keys.map(&:to_sym).sort - %i[atom rss]
    assert_equal NexusCcs::ResultCardComponent, config.view.masonry.document_component
    assert_equal NexusCcs::ListViewIconComponent, config.view.list.icon
    assert_equal NexusCcs::MasonryViewIconComponent, config.view.masonry.icon
    assert config.view.masonry.default, "mosaic is the default view"
    assert_not config.view.list.default
  end

  test "per-page options and default" do
    assert_equal [ 12, 24, 40, 96 ], config.per_page
    assert_equal 40, config.default_per_page
  end

  test "sort fields: relevance, title both ways, date both ways" do
    assert_equal %w[date-asc date-desc relevance title title-desc], config.sort_fields.keys.sort
    assert_equal "title_si desc", config.sort_fields["title-desc"].sort
  end

  test "search fields: all, title, creator, subject, description, the CJK one and Full text (the last two shown only when the core has them)" do
    assert_equal %w[all_fields cjk creator description full_text subject title], config.search_fields.keys.sort
  end

  test "advanced search is on and carries the facets" do
    assert config.advanced_search.enabled
  end

  test "digital assets are the thumbnails, with a placeholder only in the mosaic" do
    assert_equal :thumbnail_path_ssi, config.index.thumbnail_field
    assert_nil config.view.list.default_thumbnail
    assert_respond_to config.view.masonry.default_thumbnail, :call
  end

  test "mosaic placeholders vary in shape so the layout is a mosaic" do
    placeholder = config.view.masonry.default_thumbnail
    shapes = %w[a b c d e f].map { |id| placeholder.call(Struct.new(:id).new(id), {})[/placeholder-[a-z]+(?:-[0-9a-f]+)?\.svg/] }
    assert_operator shapes.uniq.size, :>, 1
  end

  test "facets use Blacklight's default filter handling (no custom builder, no tag/exclude)" do
    config.facet_fields.each_value do |facet|
      assert_nil facet.filter_query_builder, "#{facet.key} has a custom filter query builder"
      assert_nil facet.tag, "#{facet.key} is tagged"
      assert_nil facet.ex, "#{facet.key} excludes a tag"
    end
  end

  test "the advanced search form asks Solr for at most the 100 most common values of a filter, not every value" do
    params = CatalogController.blacklight_config.advanced_search.form_solr_parameters
    limits = params.select { |key, _| key.match?(/\Af\..+\.facet\.limit\z/) }

    assert_not_empty limits
    assert_equal [ 100 ], limits.values.uniq
    assert_equal "count", params["facet.sort"]
  end
end
