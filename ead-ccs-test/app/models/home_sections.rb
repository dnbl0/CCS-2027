# frozen_string_literal: true

# The record types and places of the home page (the 2026-11 homepage redesign): for each, a few of its records that may be shown
# (Collage), from which ExploreComponent takes a picture for its tile in the mosaic (NexusCcs::MosaicComponent), and a line on what it
# holds. The collections themselves are the University's listing (HomeCollections, config/home_collections.yml).
module HomeSections
  Tile = Data.define(:title, :text, :path, :image, :lead, :cta, :external, :width, :height)

  # A card of several pictures (after Google Arts & Culture's multi-picture cards): a few records that may be shown (Showcase:
  # licensed, not sensitive), each picture whole
  Collage = Data.define(:title, :text, :path, :pictures, :intro)

  IMAGES = Rails.root.join("app/assets/images") # the site's own pictures, for their sizes (ImageDimensions)
  KIND_PICTURES = 3
  PLACE_PICTURES = 6

  module_function

  # Record types: every kind (ExploreEntryPoints.kinds), each with three of its own records and a line on what it holds (the collections
  # that hold most of it, CardDescription; kept for a day). links: the overview's kinds (counts, paths).
  def kind_collages(links, helpers)
    by_label = links.index_by(&:label)
    ExploreEntryPoints.kinds.filter_map do |label, values|
      link = by_label[label] or next
      filter = Browse.field_query(ExploreEntryPoints::CLASSIFICATION_FIELD, values)
      about = Rails.cache.fetch(SuppressedRecord.cache_key("home/kind_about/v1/#{label}"), expires_in: 1.day) { CardDescription.for(filter: filter, kinds: false) }
      collage(label, link.count, helpers.search_action_path(link.query), [ filter ], helpers, KIND_PICTURES, intro: about.presence)
    end
  end

  # Places (after Google Arts & Culture's place pages): each place's spotlight, its description and six of its records for its
  # "Discover this place" wall (tiles: the overview's place tiles). Places overlap (Melbourne is in Victoria and Australia), so each
  # prefers records the places before it have not shown, and no two tabs share a picture.
  def place_collages(tiles, helpers)
    used = Set.new
    tiles.map do |tile|
      collage(tile.label, tile.count, helpers.search_action_path(tile.query), [ Browse.field_query("production_place_ssim", tile.label) ],
              helpers, PLACE_PICTURES, used, intro: tile.intro)
    end
  end

  def collage(title, count, path, fq, helpers, pictures, used = Set.new, intro: nil)
    found = Array(Showcase.call(fq: fq, highlights: [ pictures, Showcase::HIGHLIGHTS ].max)&.documents).filter_map do |document|
      src = document["thumbnail_path_ssi"].presence or next
      { src: AssetVersion.url(src), title: Array(document["title_tsim"]).first.to_s, id: document.id }
    end
    fresh, seen = found.partition { |picture| !used.include?(picture[:src]) }
    shown = fresh + seen
    shown.first(pictures).each { |picture| used << picture[:src] }
    text = count && I18n.t("home.records", count: count, number: helpers.number_with_delimiter(count))
    Collage.new(title: title, text: text, path: path, pictures: shown.first(pictures), intro: intro)
  end
end
