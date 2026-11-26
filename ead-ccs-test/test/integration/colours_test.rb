require "test_helper"
require_relative "../support/discovery_records"

# Explore by colour (/browse/colours), the Colour filter and the record page's "Looks similar" (docs/colour-and-clean-up.md).
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

  def colour_page(counts, records: [])
    lambda do |params|
      response = canned_response(params[:rows].to_i.zero? ? [] : records, total: counts.values.sum)
      response["facet_counts"]["facet_fields"]["colour_ssim"] = counts.flat_map { |name, count| [ name, count ] }
      response
    end
  end

  test "the colour page: a strip of the colours, each named, in the palette's order; each colour's card opens its wall" do
    with_seeded_menu_cache { with_canned_search(colour_counts("blue" => 12, "red" => 1_234, "white" => 3)) { get "/browse/colours?view=spectrum" } }

    assert_response :success
    assert_select "title", /\ASpectrum — Colours — /
    assert_select "h1", "Colours" # the one Browse template; the spectrum is its third view
    assert_select "nav.places-views a.places-views__link[aria-current=page][href$='view=spectrum']", "Spectrum"
    assert_select "turbo-frame#colour-explorer[data-turbo-action=advance] nav.explore-strip[aria-label=Colours]" do
      labels = css_select("a.explore-strip__swatch").map { |swatch| swatch["aria-label"] }
      assert_equal %w[Red Blue White], labels # names only: the site shows no counts
      assert_select "a.explore-strip__swatch.colours__swatch--red[href=?][title=?]", "/browse/colours?colour=red", "Red"
      assert_select "a[aria-current]", 0, "no colour chosen yet"
    end
    assert_select "h2#colours-heading", "Colours"
    # a card for each colour, in the strip's order, its name the link to its wall and its number of records under it; the canned Solr
    # has no pictures, so the cards show the colour itself
    assert_equal %w[Red Blue White], css_select("ul.colour-cards li.colour-card h3 a.colour-card__link").map { |link| link.text.squish }
    assert_select "li.colour-card:first-child a.colour-card__link[href='/browse/colours?colour=red']"
    assert_select ".colour-card__count", 0
    assert_select "li.colour-card:first-child .colour-card__pictures.colours__swatch--red[aria-hidden=true]"
  end

  test "a chosen colour: its swatch marked, then its records as a wall of squares, those mostly that colour first, and a way to all of them" do
    records = [ open_record("emu-b", colour_ssim: %w[white teal]), open_record("emu-a", colour_ssim: %w[teal white], colour_palette_ssm: %w[#0497d1 #ffffff]),
                sensitive_record("emu-s", colour_ssim: %w[teal]) ]
    with_seeded_menu_cache { with_canned_search(colour_page({ "teal" => 43, "red" => 5 }, records: records)) { get "/browse/colours?colour=teal" } }

    assert_response :success
    assert_select "title", /\ATeal — Spectrum — Colours — /
    assert_select "a.explore-strip__swatch[aria-current=page]", 1
    assert_select "a.explore-strip__swatch.colours__swatch--teal[aria-current=page]"
    assert_select "section.picture-wall[aria-labelledby=picture-wall-heading]" do
      assert_select "h2#picture-wall-heading", "Teal"
      # the colour before and after it in the strip, staying on this page
      assert_select "a.picture-wall__step[aria-label='Previous colour: Red'][href='/browse/colours?colour=red']:not([data-turbo-frame])", text: "← Red"
      assert_select "a.picture-wall__step[aria-label^='Next']", 0 # teal is last here (the spectrum's order)
      # while a picture loads, its frame shows the picture's own main colour
      assert_select "a.picture-wall__link[href='/catalog/emu-a'][style='--tint: #0497d1']"
      assert_select ".picture-wall__count", 0
      assert_select ".picture-wall__links a[data-turbo-frame=_top][href=?]", "/catalog?f%5Bcolour_ssim%5D%5B%5D=teal", text: "See them all in the search"
      assert_equal %w[/catalog/emu-a /catalog/emu-b], css_select("a.picture-wall__link").map { |link| link["href"] }, "mostly teal first; no sensitive record"
      assert_select "a.picture-wall__link[data-turbo-frame=_top] img[alt='']", 2
      assert_select "a.picture-wall__link .picture-wall__title", "Title of emu-a"
      assert_select "span.picture-wall__band.colours__swatch--teal[aria-hidden=true]"
    end
  end

  test "a colour the index does not have is no choice: the page as it is before a colour is chosen" do
    with_seeded_menu_cache { with_canned_search(colour_counts("red" => 5)) { get "/browse/colours?colour=mauve" } }
    assert_response :success
    assert_select "section.picture-wall", 0
    assert_select "h2#colours-heading", "Colours"
  end

  test "with no colours yet, or Solr down, the page says so" do
    with_seeded_menu_cache { with_canned_search(colour_counts({})) { get "/browse/colours?view=spectrum" } }
    assert_select ".colours__empty", "No colours are available yet."

    with_seeded_menu_cache { get "/browse/colours?view=spectrum" }
    assert_response :service_unavailable
    assert_select ".unavailable-note", "The colours cannot be shown right now. Please try again in a few minutes." # the one sentence
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
