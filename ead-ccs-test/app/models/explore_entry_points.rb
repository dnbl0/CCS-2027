# frozen_string_literal: true

# The home page's "Explore the collections" section: ways into the records that need no search term (the entry points Google Arts &
# Culture and Europeana lead with). It has three groups, all chosen in config/explore_kinds.yml:
#
#   collections  tiles for the real collections (collection_ssim), most records first, with the exact count
#   kinds        a short curated list of kinds of records: each is several classification_ssim values (a record with two of them counts once)
#   places, periods  a few places and periods, as plain links
#
# Every link opens all the matching records through an existing /catalog facet URL; the any_assets marker keeps the default "With a
# digital asset" filter off (docs/adr/0004). No new routes.
#
# The numbers come from one Solr request, kept for a day, and the last good answer for a month, as BrowseMenu does (CCS-147). If Solr
# cannot answer and nothing is kept, there is no overview and the home page leaves the section out.
#
# Each collection tile may carry one example image (the University's Listings component "with images"): a record of the collection whose
# asset anyone may download (AccessPolicy :open), that is not sensitive (Sensitivity), whose thumbnail this server holds so its size is
# known (ImageDimensions). It is chosen in the same refresh as the numbers (one more Solr request per collection) and kept with them.
# A tile with no such record has no image, and the section draws its designed text-only face; that is the usual case (about 137 of
# 49,000 records have an image). The Indigenous Collections tile never has one (cultural review pending, docs/explore.md). Nothing
# else about a record, and no path of a withheld record, is ever kept here.
module ExploreEntryPoints
  Image = Data.define(:id, :title, :path, :width, :height)
  # A collection tile: its name, the exact number of records, the search that opens them, an optional example image, and its tint (1..TINTS)
  Tile = Data.define(:label, :count, :query, :image, :tint)
  # A plain link: a kind of record, a place or a period
  Link = Data.define(:label, :count, :query)
  Overview = Data.define(:collections, :kinds, :places, :periods) do
    def any? = [ collections, kinds, places, periods ].any?(&:present?)
  end

  COLLECTION_FIELD = "collection_ssim"
  CLASSIFICATION_FIELD = "classification_ssim"
  OBJECT_TYPE_FIELD = "object_type_ssim"
  PLACE_FIELD = "production_place_ssim"
  DATE_FIELD = "date_start_isi"
  CONFIG_PATH = Rails.root.join("config/explore_kinds.yml")
  CACHE_KEY = "explore_entry_points/v2"
  LAST_GOOD_KEY = "explore_entry_points/last_good/v2"
  # The tints of the collection tiles (--ccs-explore-tint-1 to -6 in tokens/semantic.css)
  TINTS = 6
  # Records looked at, in id order, for each collection's example image
  IMAGE_CANDIDATES = 12
  THUMBNAIL_DIRECTORY = "/digital-assets/thumbs/"
  # BC dates are real (negative years), so the first period has no lower bound worth showing
  EARLIEST_YEAR = -10_000
  FACET_LIMIT = 2000

  def self.config = (@config ||= YAML.safe_load_file(CONFIG_PATH).freeze)

  # [label, first year, last year]
  def self.periods(this_year = Time.zone.today.year)
    config["periods"].map { |label, first, last| [ label, first, last || this_year ] }
  end

  def self.period_key(first, last) = "#{first}-#{last}"

  def self.kinds = config["kinds"].map { |kind| [ kind.fetch("label"), Array(kind.fetch("values")) ] }

  # counts: as ExploreEntryPoints.counts returns them (empty when Solr is unavailable)
  def self.overview(counts = self.counts)
    return Overview.new([], [], [], []) if counts.blank?

    Overview.new(collection_tiles(counts), kind_links(counts), place_links(counts), period_links(counts["periods"] || {}))
  end

  def self.counts(connection = nil)
    Rails.cache.fetch(CACHE_KEY, expires_in: 1.day, skip_nil: true) do
      fetched = fetch_counts(connection || Blacklight.default_index.connection)
      Rails.cache.write(LAST_GOOD_KEY, fetched, expires_in: 30.days) if fetched
      fetched
    end || Rails.cache.read(LAST_GOOD_KEY) || {}
  end

  def self.fetch_counts(connection)
    response = SolrGuard.run do
      connection.get("select", params: {
        q: "*:*", rows: 0, wt: "json", facet: true, "facet.mincount": 1, "facet.limit": FACET_LIMIT, "facet.sort": "count",
        "facet.field": [ COLLECTION_FIELD, CLASSIFICATION_FIELD, PLACE_FIELD ],
        "facet.query": kinds.map { |_label, values| Browse.field_query(CLASSIFICATION_FIELD, values) } +
                       periods.map { |_label, first, last| period_query(first, last) }
      })
    end
    fetched = parse(response)
    fetched.merge("images" => fetch_images(fetched["collections"]))
  rescue RSolr::Error::Http, RSolr::Error::ConnectionRefused, RSolr::Error::Timeout, Faraday::Error, SystemCallError, Timeout::Error => e
    Rails.logger.warn("Explore entry points unavailable: #{e.class}")
    nil
  end

  # The facet part of a Solr response, as the plain data that is kept: collections and places as [value, count] pairs, kinds as
  # [label, count, the values the index has], periods as { period key => count }. Needs no Solr, so it is tested on its own.
  def self.parse(response)
    facets = response.dig("facet_counts", "facet_fields") || {}
    queries = response.dig("facet_counts", "facet_queries") || {}
    present = facets[CLASSIFICATION_FIELD].to_a.each_slice(2).map(&:first).to_set
    {
      "collections" => collection_pairs(facets[COLLECTION_FIELD]),
      "kinds" => kinds.filter_map do |label, values|
        count = queries[Browse.field_query(CLASSIFICATION_FIELD, values)].to_i
        [ label, count, values.select { |value| present.include?(value) } ] if count.positive?
      end,
      "places" => facets[PLACE_FIELD].to_a.each_slice(2).to_a.reject { |value, _count| config.dig("places", "skip").include?(value) }.first(config.dig("places", "limit")),
      "periods" => periods.to_h { |_label, first, last| [ period_key(first, last), queries[period_query(first, last)] ] }
    }
  end

  def self.collection_pairs(list)
    rules = config["collections"]
    list.to_a.each_slice(2).to_a
        .reject { |value, count| rules["hide"].include?(value) || count.to_i < rules["minimum_records"] }
        .first(rules["limit"])
  end

  # { collection name => { id:, title:, path:, width:, height: } } for the collections that have an example record. A failure here costs
  # the images, not the numbers.
  def self.fetch_images(collection_pairs)
    collection_pairs.to_a.filter_map do |name, _count|
      next if text_only?(name)

      image = example_image("#{COLLECTION_FIELD}:#{Browse.phrase(name)}")
      [ name, image ] if image
    end.to_h
  rescue StandardError => e
    Rails.logger.warn("Explore example images unavailable: #{e.class}")
    {}
  end

  def self.text_only?(name) = config.dig("collections", "text_only").include?(name)

  # The first record, in id order, that Discovery.pickable? allows (AccessPolicy :open, not Sensitivity.sensitive?) and whose thumbnail
  # is a file this server holds. The Solr filters narrow the search; the Ruby checks decide.
  def self.example_image(group_filter)
    response = Discovery.search(
      q: "*:*", sort: "id asc", rows: IMAGE_CANDIDATES,
      fq: [ FreeReuse.filter_query, "has_digital_asset_bsi:true", "-restrictions_tsi:sensitive", "{!prefix f=thumbnail_path_ssi}#{THUMBNAIL_DIRECTORY}", group_filter ]
    )
    response.documents.each do |document|
      next unless Discovery.pickable?(document)

      path = document["thumbnail_path_ssi"].to_s
      width, height = ImageDimensions.for_path(path)
      next unless width

      title = Array(document["title_tsim"]).first.to_s.strip
      return { id: document.id.to_s, title: title.presence || "Untitled record", path: path, width: width, height: height } if path.start_with?(THUMBNAIL_DIRECTORY)
    end
    nil
  end

  def self.period_query(first, last) = "#{DATE_FIELD}:[#{first} TO #{last}]"

  def self.collection_tiles(counts)
    images = counts["images"] || {}
    counts["collections"].to_a.each_with_index.map do |(name, count), index|
      image = build_image(images[name]) unless text_only?(name)
      Tile.new(label: name, count: count.to_i, query: BrowseHubs.query(COLLECTION_FIELD, name), image: image, tint: (index % TINTS) + 1)
    end
  end

  def self.kind_links(counts)
    counts["kinds"].to_a.filter_map do |label, count, values|
      Link.new(label, count.to_i, Browse.search_query(CLASSIFICATION_FIELD, values)) if Array(values).any?
    end
  end

  def self.place_links(counts)
    counts["places"].to_a.map { |value, count| Link.new(value, count.to_i, BrowseHubs.query(PLACE_FIELD, value)) }
  end

  def self.period_links(counts)
    periods.filter_map do |label, first, last|
      count = counts[period_key(first, last)].to_i
      Link.new(label, count, BrowseHubs.period_query(first, last)) if count.positive?
    end
  end

  def self.build_image(image)
    return unless image.is_a?(Hash)

    Image.new(**image.symbolize_keys.slice(*Image.members))
  rescue ArgumentError
    nil
  end

  private_class_method :fetch_counts, :fetch_images, :example_image, :collection_pairs, :collection_tiles, :kind_links, :place_links, :period_links, :build_image
end
