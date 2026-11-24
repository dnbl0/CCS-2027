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

  test "the colour page: the colours' share as a band, then each colour by name and count, in the palette's order, opening its results" do
    with_seeded_menu_cache { with_canned_search(colour_counts("blue" => 12, "red" => 1_234, "white" => 3)) { get "/explore/colours" } }

    assert_response :success
    assert_select "title", /Explore by colour/
    assert_select "h1", "Explore by colour"
    assert_select "nav li", /Browse/
    assert_select "figure.colour-band" do
      assert_select "figcaption", /most common is red \(1,234 records\)/
      assert_select "ol.colour-band__bar[aria-hidden=true] > li.colour-band__part", 3
      assert_select "li.colour-band__part.colours__swatch--red[style*='--w: 1.0']"
    end
    assert_select "h2#colours-heading", "Colours"
    # the canned Solr has no pictures: every colour is a link after the (empty) mosaic, none lost
    links = css_select("#colours-heading ~ * a[href*='colour_ssim']")
    assert_equal [ "Red 1,234 records", "Blue 12 records", "White 3 records" ], links.map { |link| link.text.squish }
    assert_equal "/catalog?f%5Bcolour_ssim%5D%5B%5D=red", links.first["href"]
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

  test "Looks similar: the closest records by colour as the record page's cards, leaving out any without a viewable image" do
    looks_like("emu-source", %w[emu-a emu-withheld emu-c emu-sensitive emu-b])
    with_seeded_menu_cache { with_canned_search(discovery_solr(records: records)) { |seen| get "/catalog/emu-source/looks-similar"; @seen = seen } }

    assert_response :success
    assert_select "turbo-frame#looks-similar[target=_top] section#looks-similar-records[aria-labelledby=looks-similar-heading]" do
      assert_select "h2#looks-similar-heading", "Looks similar"
      assert_select "li.object-cards__item", 2
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

  test "the record page's Looks similar partial is a lazy frame, drawn only for a record with a viewable image" do
    draw = ->(record) { ApplicationController.render(partial: "catalog/looks_similar", locals: { document: SolrDocument.new(record) }) }

    html = Nokogiri::HTML5.fragment(draw.call(open_record("emu-source")))
    assert_equal "/catalog/emu-source/looks-similar", html.at_css("turbo-frame#looks-similar[loading=lazy]")["src"]
    assert_empty draw.call(open_record("emu-c", has_digital_asset_bsi: false)).strip
    assert_empty draw.call(sensitive_record("emu-sensitive")).strip
    assert_includes Rails.root.join("app/views/catalog/show.html.erb").read.lines.last, "catalog/looks_similar", "after More like this"
  end
end
