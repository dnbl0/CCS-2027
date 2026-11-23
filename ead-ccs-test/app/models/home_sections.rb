# frozen_string_literal: true

# The picture tiles of the home page's mosaic sections (NexusCcs::MosaicComponent; the 2026-11 homepage redesign wireframe,
# "Collections Navigator Homepage Redesign"): the five museums, visiting them, and the named collections inside them. Each section
# is a few small tiles and one large lead tile with a line of text and a call to action. The words and pictures come from what the
# site already has: config/pages.yml (each museum's name, blurb, banner and visiting details) and the index (a picture for each named
# collection). Nothing here is new copy.
module HomeSections
  Tile = Data.define(:title, :text, :path, :image, :lead, :cta, :external)

  # The five museums, the one that leads the Explore section, and the one that leads Visit
  MUSEUMS = %w[university-art-collection medical-history-museum grainger-museum harry-brookes-allen-museum henry-forman-atkinson-dental-museum].freeze
  EXPLORE_LEAD = "university-art-collection"
  VISIT_LEAD = "grainger-museum"
  NAMED_SHOWN = 8

  module_function

  # Explore the collections: four museums, then the lead. The two longest names take the two wide tiles (the first and the fourth),
  # so no name is squeezed into a narrow one. No record counts (Dean, 2026-11-23). helpers: for the paths and pictures.
  def collections(helpers)
    others = (MUSEUMS - [ EXPLORE_LEAD ]).sort_by { |slug| -museum(slug)["name"].length }
    small = [ others[0], others[2], others[3], others[1] ].map { |slug| museum_tile(slug, helpers, text: nil) }
    small + [ museum_tile(EXPLORE_LEAD, helpers, text: museum(EXPLORE_LEAD)["blurb"], lead: true, cta: I18n.t("home.collections.cta")) ]
  end

  # Visit the collections: the lead first (it sits on the left), each tile saying when the museum is open, linking to its visitor page
  def visit(helpers)
    lead = museum(VISIT_LEAD)
    lead_text = [ visit_line(lead, "Opening hours"), visit_line(lead, "Accessibility") ].compact.map { |line| line.match?(/[.!?]\z/) ? line : "#{line}." }.join(" ")
    [ visit_tile(VISIT_LEAD, helpers, text: lead_text, lead: true, cta: I18n.t("home.visit.cta")) ] +
      (MUSEUMS - [ VISIT_LEAD ]).map { |slug| visit_tile(slug, helpers, text: visit_line(museum(slug), "Opening hours")) }
  end

  # Collections within the collections: the named collections that have a picture, largest first; the largest leads (last in the
  # list, at the right). values: Categories.values for named collections ([{ "value", "count", "image" => { "path" } }]).
  def named(values, helpers)
    pictured = Array(values).select { |value| value.dig("image", "path").present? }.first(NAMED_SHOWN)
    return [] if pictured.size < NAMED_SHOWN

    tiles = pictured.map.with_index do |value, index|
      name = value["value"]
      Tile.new(title: name, text: nil,
               path: helpers.collection_landing_path(kind: "named-collections", slug: Browse::Slug.build("named-collections", name)),
               image: value.dig("image", "path"), lead: index.zero?, cta: (I18n.t("home.collections.cta") if index.zero?), external: false)
    end
    tiles.drop(1) + [ tiles.first ]
  end

  def museum(slug) = SitePages.collection(slug)

  def museum_tile(slug, helpers, text:, lead: false, cta: nil)
    data = museum(slug)
    Tile.new(title: data["name"], text: text, lead: lead, cta: cta, external: false, image: banner(data, helpers),
             path: helpers.collection_landing_path(kind: "collections", slug: Browse::Slug.build("collections", data["facet_value"])))
  end

  def visit_tile(slug, helpers, text:, lead: false, cta: nil)
    data = museum(slug)
    Tile.new(title: data["name"], text: text, lead: lead, cta: cta, external: data["visit_url"].present?, image: banner(data, helpers),
             path: data["visit_url"].presence || helpers.collection_landing_path(kind: "collections", slug: Browse::Slug.build("collections", data["facet_value"])))
  end

  def banner(data, helpers) = data["banner"].present? ? helpers.asset_path("site/banners/#{data['banner']}") : nil

  # The first paragraph of a museum's visiting detail ("Opening hours"), as plain text
  def visit_line(data, label)
    section = Array(data["visit"]).find { |item| item["label"] == label }
    text = Array(section&.dig("paragraphs")).first
    text && ActionController::Base.helpers.strip_tags(text.gsub(%r{<br\s*/?>}, ", ")).squish
  end
end
