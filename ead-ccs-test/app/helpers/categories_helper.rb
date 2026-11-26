# frozen_string_literal: true

# Browse by category (categories/index and show) on the home page's layouts (docs/card-layouts.md): each way of grouping gets one of the
# home page's section layouts, so the page reads as the home page does, the layouts taking turns and two of them on bands of colour.
module CategoriesHelper
  # slug => [layout, how many cards, band colour or nil]. stack: Google's fanned stack; bare: its picture-only stack; cluster: its block
  # of different sizes; carousel: its story carousel (the eras, a sequence in time)
  CATEGORY_LAYOUTS = {
    "object-types" => [ :stack, 5, "var(--ccs-explore-tint-3)" ],
    "classifications" => [ :cluster, 4, nil ],
    "materials" => [ :bare, 4, nil ],
    "regions" => [ :stack, 5, nil ],
    "eras" => [ :carousel, 8, nil ],
    "collections" => [ :cluster, 4, "var(--ccs-explore-tint-2)" ],
    "named-collections" => [ :stack, 5, nil ]
  }.freeze

  # The Browse page's sections, in order (docs/ia-audit-handover.md): a category's values in its layout, or a hub's own cards (makers,
  # subjects). heading and intro, where given, name the section by the page its "See all" opens (regions are Places, eras Time).
  BROWSE_SECTIONS = [
    { dimension: "collections" }, { dimension: "object-types" }, { dimension: "classifications" }, { dimension: "materials" },
    # Places and Time show what their pages show (places; centuries and decades), not world regions and catalogue eras (26 Nov 2026)
    { hub: "places" }, { hub: "periods" },
    { hub: "makers" }, { hub: "subjects" }, { dimension: "named-collections" }
  ].freeze

  def category_layout(dimension) = CATEGORY_LAYOUTS.fetch(dimension.slug, [ :stack, 5, nil ])

  # A section's cards: the values with the most records whose picture no earlier section used (the page shows no picture twice), a value
  # with no picture of its own borrowing one of its records' from anywhere; the eras then in time order
  def category_section_tiles(dimension, tiles, count)
    @category_pictures_used ||= Set.new
    candidates = tiles.first(count * 3)
    borrowed = borrowed_pictures(dimension, candidates)
    chosen = []
    candidates.each do |category|
      break if chosen.size == count

      tile = category_tile(category, dimension)
      picture = borrowed&.value(dimension.field, category.value)
      tile = tile.with(image: DamImage.sized(AssetVersion.url(picture.src), 600), width: nil, height: nil) if tile.image.nil? && picture
      next unless tile.image && @category_pictures_used.add?(category_picture_key(tile.image)) # a picture already on the page: passed over
      chosen << tile
    end
    dimension.slug == "eras" ? chosen.sort_by { |tile| Explore::Timeline.era_order(tile.title) } : chosen # the eras' carousel runs in time
  end

  private

  # A picture from anywhere in the collections for each value that has none of its own (most object types): one grouped request for the
  # section's values, kept for a day (Browse::FacetPictures#prepare, as Explore by colour's tiles); nil when every value has its own
  def borrowed_pictures(dimension, categories)
    missing = categories.reject { |category| NexusCcs::ExploreCardComponent.image?(category, remote: true) }
    Browse::FacetPictures.new([]).prepare(missing.map { |category| [ dimension.field, [ category.value ] ] }) if missing.any?
  end

  # The same picture at any size: its file name
  def category_picture_key(src)
    File.basename(URI.parse(src.to_s).path.to_s)
  rescue URI::InvalidURIError
    src.to_s
  end
end
