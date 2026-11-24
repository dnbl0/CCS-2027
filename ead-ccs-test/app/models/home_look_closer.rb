# frozen_string_literal: true

# The home page's "Look closer" band (NexusCcs::LookCloserComponent; after Google Arts & Culture's "Guess the artwork from the pieces",
# looked at 2026-11-24): square close-ups of one record's picture, then a line inviting a guess and a link to the record. The record is one
# of config/home_look_closer.yml's, a different one each day; the band takes a pale tint of the picture's own main colour.
#
# The close-ups are the busiest parts of the picture, not blank paper or mount: the picture is read small (Colour::Fetcher's 64-pixel PNG
# from the DAM, Colour::Png), each pixel's detail is how much it differs from its neighbours, and the squares with the most detail are
# chosen, at a few sizes, overlapping little. Worked out once a month per record; with no pixels to read, the squares are spread over the
# middle of the picture instead.
module HomeLookCloser
  Pick = Data.define(:id, :title, :maker, :image, :tint, :crops)
  # the square's left and top and its width, as shares of the picture's width and height (size: of its width); aspect: the picture's
  # width over its height
  Crop = Data.define(:x, :y, :size, :aspect)

  COUNT = 20                       # the band's squares (LookCloserComponent's pattern)
  SIZES = [ 0.13, 0.18, 0.24, 0.3 ].freeze # a square's width as a share of the picture's width
  OVERLAP = 0.25                   # two squares share at most this much of the smaller one
  FIELDS = %w[id title_tsim creator_ssim thumbnail_path_ssi colour_palette_ssm].freeze

  module_function

  def ids = @ids ||= Array(YAML.safe_load_file(Rails.root.join("config/home_look_closer.yml"))["records"]).map(&:to_s)

  # Today's record and its close-ups, or nil (none of the records can be shown, or Solr cannot answer)
  def today(date: Date.current, repository: nil, fetcher: Colour::Fetcher.new)
    documents = Rails.cache.fetch(SuppressedRecord.cache_key("home_look_closer/v1/#{date}"), expires_in: 1.day, skip_nil: true) do
      fetch(repository || Blacklight.default_index)
    end
    return if documents.blank?

    document = documents[date.yday % documents.size]
    crops = Rails.cache.fetch("home_look_closer/crops/v2/#{document['id']}", expires_in: 30.days) { crops_for(document["src"], fetcher) }
    Pick.new(id: document["id"], title: document["title"], maker: document["maker"], image: DamImage.sized(document["src"], 1600),
             tint: tint(document["colour"]), crops: crops.map { |crop| Crop.new(**crop.symbolize_keys) })
  end

  # The records that may be shown, in the list's order: [{ "id", "title", "maker", "src", "colour" }], or nil when Solr cannot answer
  def fetch(repository)
    response = repository.search(params: { q: "*:*", defType: "lucene", qt: "select", fq: [ Browse.field_query("id", ids) ] + Browse::Cards::THUMBNAIL_FILTERS,
                                           rows: ids.size, fl: (Browse::Profile::FIELDS + FIELDS).uniq.join(","), facet: false })
    found = response.documents.select { |document| AccessPolicy.view?(document) && !Sensitivity.sensitive?(document) && DamImage::HOSTS.include?(URI.parse(document["thumbnail_path_ssi"].to_s).host) }
    found.sort_by { |document| ids.index(document.id.to_s) }.map do |document|
      { "id" => document.id.to_s, "title" => Array(document["title_tsim"]).first.to_s.strip.presence || "Untitled record",
        "maker" => Array(document["creator_ssim"]).first, "src" => document["thumbnail_path_ssi"].to_s, "colour" => Array(document["colour_palette_ssm"]).first }
    end
  rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable, URI::InvalidURIError => e
    Rails.logger.warn("Look closer unavailable: #{e.class}")
    nil
  end

  # [{ "x", "y", "size" }] for a picture: its busiest squares, or squares over its middle when it cannot be read
  def crops_for(src, fetcher)
    png = Colour::Png.new(fetcher.png(src))
    pixels = png.pixels
    return spread unless png.width && pixels.size == png.width * png.height

    busiest(pixels.map { |r, g, b| (0.299 * r) + (0.587 * g) + (0.114 * b) }.each_slice(png.width).to_a)
  rescue Colour::Fetcher::Refused, Colour::Fetcher::Failed, Colour::Png::Unsupported => e
    Rails.logger.info("Look closer: picture not read (#{e.class.name.demodulize})")
    spread
  end

  # The squares with the most detail (the mean difference of each pixel from its right and lower neighbours), largest first among equals,
  # overlapping little; [] when the picture is too small to cut
  def busiest(rows)
    height = rows.size
    width = rows.first.size
    detail = Array.new(height) { |y| Array.new(width) { |x| ((rows[y][x] - rows[y][[ x + 1, width - 1 ].min]).abs + (rows[y][x] - rows[[ y + 1, height - 1 ].min][x]).abs) } }
    sum = integral(detail)
    candidates = SIZES.flat_map do |share|
      side = (share * width).round
      next [] if side < 3 || side > height

      step = [ side / 3, 1 ].max
      (0..(height - side)).step(step).flat_map do |top|
        (0..(width - side)).step(step).map do |left|
          total = sum[top + side][left + side] - sum[top][left + side] - sum[top + side][left] + sum[top][left]
          # its mean detail, a little in favour of the larger squares (a small one is easily all edge)
          { left: left, top: top, side: side, score: total.to_f / (side * side) * (share**0.35) }
        end
      end
    end
    chosen = []
    candidates.sort_by { |candidate| [ -candidate[:score], -candidate[:side] ] }.each do |candidate|
      break if chosen.size == COUNT
      chosen << candidate if chosen.none? { |other| overlap(candidate, other) > OVERLAP }
    end
    aspect = width.fdiv(height).round(4)
    chosen.map { |square| { "x" => square[:left].fdiv(width).round(4), "y" => square[:top].fdiv(height).round(4), "size" => square[:side].fdiv(width).round(4), "aspect" => aspect } }
  end

  # Summed-area table: any square's total detail in four lookups
  def integral(grid)
    table = Array.new(grid.size + 1) { Array.new(grid.first.size + 1, 0) }
    grid.each_with_index do |row, y|
      row.each_with_index { |value, x| table[y + 1][x + 1] = value + table[y][x + 1] + table[y + 1][x] - table[y][x] }
    end
    table
  end

  def overlap(one, other)
    across = [ one[:left] + one[:side], other[:left] + other[:side] ].min - [ one[:left], other[:left] ].max
    down = [ one[:top] + one[:side], other[:top] + other[:side] ].min - [ one[:top], other[:top] ].max
    return 0 if across <= 0 || down <= 0

    (across * down).fdiv([ one[:side], other[:side] ].min**2)
  end

  # Without pixels: squares of the sizes in turn, over the middle three-fifths of the picture (its edges are most often mount or margin);
  # the picture's shape is not known, so it is taken as 4:3
  def spread
    Array.new(COUNT) do |index|
      share = SIZES[index % SIZES.size]
      { "x" => (0.2 + ((0.6 - share).clamp(0, 1) * ((index * 7) % 11) / 10.0)).round(4), "y" => (0.2 + (0.6 * ((index * 5) % 9) / 8.0)).round(4), "size" => share, "aspect" => 1.333 }
    end
  end

  # A pale tint of the picture's main colour for the band: mixed with white until navy text on it passes 7:1 (and at least half white),
  # so it reads as that colour without competing with the close-ups; the site's pale grey when the colour is not known
  def tint(hex)
    return nil unless hex.to_s.match?(/\A#\h{6}\z/)

    rgb = hex.delete("#").scan(/../).map { |part| part.to_i(16) }
    0.5.step(0.95, 0.05) do |white|
      mixed = rgb.map { |value| (value + ((255 - value) * white)).round }
      return format("#%02x%02x%02x", *mixed) if contrast(mixed, [ 0x00, 0x0f, 0x46 ]) >= 7
    end
    "#f3f3f6"
  end

  def contrast(one, other)
    light, dark = [ luminance(one), luminance(other) ].sort.reverse
    (light + 0.05) / (dark + 0.05)
  end

  def luminance(rgb)
    r, g, b = rgb.map { |value| value / 255.0 }.map { |c| c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }
    (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
  end
end
