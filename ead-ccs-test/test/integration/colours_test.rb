require "test_helper"
require_relative "../support/discovery_records"

# Explore by colour (/explore/colours), the Colour filter and the record page's "Looks similar" (docs/colour-and-clean-up.md).
# Solr is stood in for, so these run in the CI job that has no core.
class ColoursTest < ActionDispatch::IntegrationTest
  include DiscoveryRecords

  def colour_counts(counts)
    lambda do |params|
      response = canned_response([], total: counts.values.sum)
      response["facet_counts"]["facet_fields"]["colour_ssim"] = counts.flat_map { |name, count| [ name, count ] }
      response
    end
  end

  test "the colour page lists each colour by name with its count, linking to the results filtered by it" do
    with_seeded_menu_cache { with_canned_search(colour_counts("blue" => 12, "red" => 1_234, "white" => 3)) { get "/explore/colours" } }

    assert_response :success
    assert_select "title", /Explore by colour/
    assert_select "h1", "Explore by colour"
    assert_select "ul.colours__list > li", 3
    assert_select "ul.colours__list li:first-child a.colours__link[href=?]", "/catalog?f%5Bcolour_ssim%5D%5B%5D=red" do
      assert_select ".colours__swatch.colours__swatch--red[aria-hidden=true]"
      assert_select ".colours__name", "Red"
      assert_select ".colours__count", "1,234 records"
    end
    assert_equal %w[Red Blue White], css_select(".colours__name").map { |name| name.text.strip }
  end

  test "with no colours yet, or Solr down, the page says so" do
    with_seeded_menu_cache { with_canned_search(colour_counts({})) { get "/explore/colours" } }
    assert_select ".colours__empty", "No colours are available yet."

    with_seeded_menu_cache { get "/explore/colours" }
    assert_response :service_unavailable
    assert_select ".colours__empty", /cannot be shown just now/
  end

  test "the Colour filter sits under Digital Asset Format Type, names its values, and is not on the Advanced search form" do
    facet = CatalogController.blacklight_config.facet_fields["colour_ssim"]
    assert_equal "Colour", facet.label
    assert_equal false, facet.include_in_advanced_search
    keys = CatalogController.blacklight_config.facet_fields.keys
    assert_equal "colour_ssim", keys[keys.index("digital_asset_format_ssim") + 1]
    assert_equal "Teal", ApplicationController.helpers.colour_facet_label("teal")
  end

  def looks_like(source, ids)
    ColourNeighbour.create!(record_id: source, neighbour_ids: ids, computed_at: Time.current)
  end

  def records = [ open_record("emu-source"), open_record("emu-a"), open_record("emu-b"), open_record("emu-c", has_digital_asset_bsi: false),
                  withheld_record("emu-withheld"), sensitive_record("emu-sensitive") ]

  test "Looks similar: the closest records by colour as a panel of result cards, leaving out any without a viewable image" do
    looks_like("emu-source", %w[emu-a emu-withheld emu-c emu-sensitive emu-b])
    with_seeded_menu_cache { with_canned_search(discovery_solr(records: records)) { |seen| get "/catalog/emu-source/looks-similar"; @seen = seen } }

    assert_response :success
    assert_select "turbo-frame#more-colours[target=_top]" do
      assert_select "h2", count: 0 # the tab names it
      assert_select "li.discover-cards__item", 2
      assert_select "a[href=?]", "/catalog/emu-a"
      assert_select "a[href=?]", "/catalog/emu-b"
    end
    assert_equal 2, @seen.size, "the record, then its neighbours: one request each"
  end

  test "Looks similar answers 204 with fewer than two records to show or no neighbours, and 404 for an unknown record" do
    looks_like("emu-source", %w[emu-a emu-withheld])
    with_seeded_menu_cache { with_canned_search(discovery_solr(records: records)) { get "/catalog/emu-source/looks-similar" } }
    assert_response :no_content

    with_seeded_menu_cache { with_canned_search(discovery_solr(records: records)) { get "/catalog/emu-b/looks-similar" } }
    assert_response :no_content

    with_seeded_menu_cache { with_canned_search(discovery_solr(records: records)) { get "/catalog/emu-nothing/looks-similar" } }
    assert_response :not_found
  end

  test "Looks similar is offered only for a record with a viewable image: the second part of the Similar tab of the record page's You may be interested in" do
    assert LooksSimilar.eligible?(SolrDocument.new(open_record("emu-source")))
    assert_not LooksSimilar.eligible?(SolrDocument.new(open_record("emu-c", has_digital_asset_bsi: false)))
    assert_not LooksSimilar.eligible?(SolrDocument.new(sensitive_record("emu-sensitive")))
    assert_includes Rails.root.join("app/components/nexus_ccs/more_from_collections_component.rb").read, "looks_similar_path"
  end
end
