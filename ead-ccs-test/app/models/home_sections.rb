# frozen_string_literal: true

# The cards of the home page's picture sections (the 2026-11 homepage redesign, after Google Arts & Culture's mixed layouts): the
# collections and the named collections inside them as tiles for a fluid mosaic (NexusCcs::MosaicComponent), and the multi-picture
# cards of Record types and Places (Collage). Each section's first tile is its lead, with a line of text and a call to action. A tile
# carries its picture's size when it is known, so the mosaic can give it its own shape without cropping. The words and pictures come
# from what the site already has: config/pages.yml (the lead's blurb), the Explore tiles (ExploreEntryPoints) and the index.
module HomeSections
  Tile = Data.define(:title, :text, :path, :image, :lead, :cta, :external, :width, :height)

  # A card of several pictures (after Google Arts & Culture's multi-picture cards): a few records that may be shown (Showcase:
  # licensed, not sensitive), each picture whole
  Collage = Data.define(:title, :text, :path, :pictures)

  # The collection that leads the Explore section
  EXPLORE_LEAD = "university-art-collection"
  NAMED_SHOWN = 8
  IMAGES = Rails.root.join("app/assets/images") # the site's own pictures, for their sizes (ImageDimensions)
  KIND_PICTURES = 3
  PLACE_PICTURES = 4

  module_function

  # Explore the collections: every collection (Dean, 2026-11-23), the University Art Collection first as the lead with its blurb.
  # tiles: the Explore tiles (ExploreEntryPoints, each with its picture and size); a tile kept text only (Indigenous Collections,
  # ExploreEntryPoints.text_only?) has no picture.
  def collections(tiles, helpers)
    lead_name = museum(EXPLORE_LEAD)["facet_value"]
    leads, others = tiles.partition { |tile| tile.label == lead_name }
    (leads + others).map.with_index do |tile, index|
      lead = index.zero? && tile.label == lead_name
      image = NexusCcs::ExploreCardComponent.image?(tile) ? tile.image : nil
      Tile.new(title: tile.label, text: (museum(EXPLORE_LEAD)["blurb"] if lead), path: helpers.search_action_path(tile.query),
               image: image && AssetVersion.url(image.path), lead: lead, cta: (I18n.t("home.collections.cta") if lead), external: false,
               width: image&.width, height: image&.height)
    end
  end

  # Collections within the collections: the named collections that have a picture, largest first; the largest leads. values:
  # Categories.values for named collections ([{ "value", "count", "image" => { "path" } }]).
  def named(values, helpers)
    pictured = Array(values).select { |value| value.dig("image", "path").present? }.first(NAMED_SHOWN)
    return [] if pictured.size < NAMED_SHOWN

    pictured.map.with_index do |value, index|
      name = value["value"]
      Tile.new(title: name, text: nil,
               path: helpers.collection_landing_path(kind: "named-collections", slug: Browse::Slug.build("named-collections", name)),
               image: value.dig("image", "path"), lead: index.zero?, cta: (I18n.t("home.collections.cta") if index.zero?), external: false,
               width: value.dig("image", "width"), height: value.dig("image", "height"))
    end
  end

  # Record types: every kind (ExploreEntryPoints.kinds), each with three of its own records. links: the overview's kinds (counts, paths).
  def kind_collages(links, helpers)
    by_label = links.index_by(&:label)
    ExploreEntryPoints.kinds.filter_map do |label, values|
      link = by_label[label] or next
      collage(label, link.count, helpers.search_action_path(link.query),
              [ Browse.field_query(ExploreEntryPoints::CLASSIFICATION_FIELD, values) ], helpers, KIND_PICTURES)
    end
  end

  # Places: each place's preview, four of its records (tiles: the overview's place tiles). Places overlap (Melbourne is in Victoria
  # and Australia), so each prefers records the places before it have not shown, and no two rows share a thumbnail.
  def place_collages(tiles, helpers)
    used = Set.new
    tiles.map do |tile|
      collage(tile.label, tile.count, helpers.search_action_path(tile.query), [ Browse.field_query("production_place_ssim", tile.label) ],
              helpers, PLACE_PICTURES, used)
    end
  end

  def collage(title, count, path, fq, helpers, pictures, used = Set.new)
    found = Array(Showcase.call(fq: fq)&.documents).filter_map do |document|
      src = document["thumbnail_path_ssi"].presence or next
      { src: AssetVersion.url(src), title: Array(document["title_tsim"]).first.to_s }
    end
    fresh, seen = found.partition { |picture| !used.include?(picture[:src]) }
    shown = fresh + seen
    shown.first(pictures).each { |picture| used << picture[:src] }
    text = count && I18n.t("home.records", count: count, number: helpers.number_with_delimiter(count))
    Collage.new(title: title, text: text, path: path, pictures: shown.first(pictures))
  end

  def museum(slug) = SitePages.collection(slug)
end
