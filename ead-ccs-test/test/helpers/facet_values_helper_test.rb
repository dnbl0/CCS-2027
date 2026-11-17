require "test_helper"

class FacetValuesHelperTest < ActionView::TestCase
  test "the access tiers read as the record page words them" do
    assert_equal "Open: view and download", access_tier_facet_label("open")
    assert_equal "View only", access_tier_facet_label("view_only")
    assert_equal "Available on request", access_tier_facet_label("request")
  end

  test "the Digital asset Access Condition filter shows its values through the helper" do
    facet = CatalogController.blacklight_config.facet_fields.fetch("dam_access_tier_ssi")
    assert_equal :access_tier_facet_label, facet.helper_method
    assert_equal "Digital asset Access Condition", facet.label
  end

  test "the License type filter reads the DAM licence" do
    assert_equal "License type", CatalogController.blacklight_config.facet_fields.fetch("dam_licence_ssim").label
  end
end
