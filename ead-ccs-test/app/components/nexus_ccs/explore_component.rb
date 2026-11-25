# frozen_string_literal: true

module NexusCcs
  # The home page's "Explore the collections" section. A Fraunces H2 and one line, then three groups (ExploreEntryPoints, config/explore_kinds.yml):
  #   1. "Browse by collection": one tile per collection, as the University's Listings component (16:10 face, the whole tile is the one link,
  #      its title an H3 inside the link, the exact count in the same link). A tile's face is a tinted, typographic one by default; an example
  #      image replaces it only when ExploreEntryPoints kept one (open, not sensitive, a held thumbnail), shown whole. On a phone a tile is a row.
  #   2. "Kinds of records": a plain grouped list of arrow links, as on the University Library's collections page.
  #   3. "Place and time": two short lists of arrow links in disclosures (closed on a phone), each with a "See all" link to its browse page.
  # Renders nothing when there is nothing to show (Solr down and nothing kept).
  class ExploreComponent < ViewComponent::Base
    KINDS_SHOWN = 5 # object types in the home page's stack
    PLACES_SHOWN = 5 # places in the home page's stack
    def initialize(overview: ExploreEntryPoints.overview)
      @overview = overview
    end

    attr_reader :overview

    def render? = overview.any?

    def count_label(count) = t("explore.count", count: count, number: helpers.number_with_delimiter(count))

    # The first letters of the collection's first two words (UA, MH, GM): the typographic face of a tile with no picture (decoration, hidden from assistive technology)
    def monogram(tile)
      words = tile.label.to_s.split
      return words.first if words.first.to_s.match?(/\A\d/) # a period: its first year ("2000"), not "2O"

      words.first(2).map { |word| word[0].to_s.upcase }.join
    end

    # Whether the tile has a picture to draw. The picture is a record's thumbnail, so only a record whose asset anyone may download and that
    # is not sensitive is ever given here (ExploreEntryPoints); this is the second lock, not the only one. The Indigenous Collections tile is
    # always text only (cultural review pending).
    def image?(tile) = ExploreCardComponent.image?(tile)

    def image_path(tile) = AssetVersion.url(tile.image.path)

    # The homepage redesign's record types and places (HomeSections)
    def kind_collages = @kind_collages ||= HomeSections.kind_collages(overview.kinds, helpers)

    def place_collages = @place_collages ||= HomeSections.place_collages(overview.place_tiles, helpers)

    # Object types (the first five, as the stack's cards) and Places (as mosaic tiles, the first leading): one picture of each, its name,
    # and a line on what its page holds (the kinds of record and the collections, CardDescription, worked out from its own records) where a
    # number of records was. A place opens its own page.
    def kind_tiles
      @kind_tiles ||= begin
        about = Array(overview.kind_tiles).to_h { |tile| [ tile.label, tile.intro ] }
        kind_collages.first(KINDS_SHOWN).map { |collage| collage_tile(collage, collage.path, about[collage.title].presence || collage.intro, false) }
      end
    end

    def place_tiles
      @place_tiles ||= place_collages.first(PLACES_SHOWN).each_with_index.map do |collage, index|
        collage_tile(collage, Browse.path_for("places", collage.title) || collage.path, collage.intro, index.zero?)
      end
    end

    # Each tile's picture is the first of its records' pictures that no tile before it on the page has used (Australia, Melbourne and
    # Prints and drawings would otherwise share one print)
    def collage_tile(collage, path, about, lead)
      picture = collage.pictures.find { |candidate| fresh?(candidate[:src]) } || collage.pictures.first
      used_pictures << picture_key(picture[:src]) if picture
      HomeSections::Tile.new(title: collage.title, text: about.presence, path: path, image: picture && DamImage.sized(picture[:src], 600),
                             lead: lead, cta: nil, external: false, width: nil, height: nil)
    end

    # Time as the same tiles: the period's picture (one no tile above has used, else none), its name and what it holds, the first leading
    def period_tiles
      @period_tiles ||= overview.period_tiles.each_with_index.map do |tile, index|
        image = ExploreCardComponent.image?(tile, remote: true) ? DamImage.sized(AssetVersion.url(tile.image.path), 1000) : nil # a carousel slide: large
        image = nil if image && !fresh?(image)
        used_pictures << picture_key(image) if image
        HomeSections::Tile.new(title: tile.label, text: tile.intro.presence, path: helpers.search_action_path(tile.query),
                               image: image, lead: index.zero?, cta: nil, external: false, width: (tile.image.width if image), height: (tile.image.height if image))
      end
    end

    # Each period's years, the bold line of its card ("1800–1899", "Up to 1799", "2000 to today"), from its search's year range
    def period_spans
      overview.period_tiles.map do |tile|
        range = tile.query.dig(:range, ExploreEntryPoints::DATE_FIELD) || tile.query.dig("range", ExploreEntryPoints::DATE_FIELD) || {}
        first, last = range.values_at(:begin, :end).zip(range.values_at("begin", "end")).map(&:compact).map(&:first)
        first = nil if first.to_i <= -10_000 # the earliest period's open start
        last = nil if last.to_i >= Time.zone.today.year # the latest period runs to this year
        if first && last then t("home.periods.span", first: first, last: last)
        elsif last then t("home.periods.up_to", last: last)
        elsif first then t("home.periods.from", first: first)
        end
      end
    end

    # "What do you want to explore?": Explore by place, by time and by colour, and the stories, as Google's picture-only stack. Each takes a
    # picture no section above has used, from its own kind where it can (a place's for Places), else any record type's or place's
    def way_tiles
      @way_tiles ||= begin
        kind_tiles
        place_tiles
        period_tiles
        pool = (place_collages + kind_collages).flat_map(&:pictures)
        own = { places: place_collages.flat_map(&:pictures), time: [], colour: [], stories: kind_collages.flat_map(&:pictures) }
        paths = { places: helpers.explore_places_path, time: helpers.explore_time_path, colour: helpers.explore_colours_path, stories: helpers.stories_path }
        paths.map do |key, path|
          picture = (own[key] + pool).find { |candidate| fresh?(candidate[:src]) }
          used_pictures << picture_key(picture[:src]) if picture
          HomeSections::Tile.new(title: t("home.ways.#{key}"), text: nil, path: path, image: picture && DamImage.sized(picture[:src], 800),
                                 lead: false, cta: nil, external: false, width: nil, height: nil)
        end
      end
    end

    # Today's "Look closer" band (HomeLookCloser), or nil
    def look_closer = defined?(@look_closer) ? @look_closer : (@look_closer = HomeLookCloser.today)

    # The pictures the page already shows, starting with today's Look closer record: "What do you want to explore?" picks its pictures
    # (and so the Time cards') before the band renders, so the band's picture is set aside first, not when it is drawn
    def used_pictures = @used_pictures ||= Set.new(look_closer ? [ picture_key(look_closer.image) ] : [])

    def fresh?(src) = !used_pictures.include?(picture_key(src))

    # The same picture at any size or address: its file name
    def picture_key(src) = File.basename(URI.parse(src.to_s).path.to_s) rescue src.to_s
  end
end
