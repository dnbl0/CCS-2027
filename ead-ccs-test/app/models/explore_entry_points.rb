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
  Tile = Data.define(:label, :count, :query, :image, :tint, :intro) do
    def initialize(label:, count:, query:, image:, tint:, intro: nil) = super
  end
  # A plain link: a kind of record, a place or a period
  Link = Data.define(:label, :count, :query)
  Overview = Data.define(:collections, :kinds, :places, :periods, :kind_tiles, :place_tiles, :period_tiles) do
    def any? = [ collections, kinds, places, periods ].any?(&:present?)
  end
  # FILM COPY: Record types, Places and Time are each a row of this many tiles
  ROW = 4
  # The Places section is a row that scrolls sideways, so it holds more than a row of tiles
  PLACES_SHOWN = 8

  COLLECTION_FIELD = "collection_ssim"
  CLASSIFICATION_FIELD = "classification_ssim"
  OBJECT_TYPE_FIELD = "object_type_ssim"
  PLACE_FIELD = "production_place_ssim"
  DATE_FIELD = "date_start_isi"
  CONFIG_PATH = Rails.root.join("config/explore_kinds.yml")
  CACHE_KEY = "explore_entry_points/v6"
  LAST_GOOD_KEY = "explore_entry_points/last_good/v6"
  # The tints of the collection tiles (--ccs-explore-tint-1 to -6 in tokens/semantic.css)
  TINTS = 6
  # Records looked at, in id order, for each collection's example image
  IMAGE_CANDIDATES = 40
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
    return Overview.new([], [], [], [], [], [], []) if counts.blank?

    kinds = kind_links(counts); places = place_links(counts); periods = period_links(counts["periods"] || {})
    Overview.new(collection_tiles(counts), kinds, places, periods,
                 link_tiles(kinds, counts["kind_images"], counts["kind_intros"], prefer_images: true), link_tiles(places, counts["place_images"], counts["place_intros"], prefer_images: true, limit: PLACES_SHOWN),
                 link_tiles(periods, counts["period_images"], counts["period_intros"]))
  end

  def self.counts(connection = nil)
    Rails.cache.fetch(SuppressedRecord.cache_key(CACHE_KEY), expires_in: 1.day, skip_nil: true) do
      fetched = fetch_counts(connection || Blacklight.default_index.connection)
      Rails.cache.write(SuppressedRecord.cache_key(LAST_GOOD_KEY), fetched, expires_in: 30.days) if fetched
      fetched
    end || Rails.cache.read(SuppressedRecord.cache_key(LAST_GOOD_KEY)) || {}
  end

  def self.fetch_counts(connection)
    response = SolrGuard.run do
      connection.get("select", params: {
        q: "*:*", rows: 0, wt: "json", facet: true, "facet.mincount": 1, "facet.limit": FACET_LIMIT, "facet.sort": "count",
        "facet.field": [ COLLECTION_FIELD, CLASSIFICATION_FIELD, PLACE_FIELD ],
        "facet.query": kinds.map { |_label, values| SolrQuery.field(CLASSIFICATION_FIELD, values) } +
                       periods.map { |_label, first, last| period_query(first, last) }
      })
    end
    fetched = parse(response)
    fetched = fetched.merge("images" => fetch_images(fetched["collections"]))
    fetched = fetched.merge(fetch_link_images(fetched))
    fetched.merge(fetch_link_intros(fetched))
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
        count = queries[SolrQuery.field(CLASSIFICATION_FIELD, values)].to_i
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

      image = example_image("#{COLLECTION_FIELD}:#{SolrQuery.phrase(name)}")
      [ name, image ] if image
    end.to_h
  rescue StandardError => e
    Rails.logger.warn("Explore example images unavailable: #{e.class}")
    {}
  end

  # FILM COPY: one example picture for each record type, place and period (the same rule as the collection tiles' pictures)
  def self.fetch_link_images(fetched)
    kinds = fetched["kinds"].to_a.to_h { |label, _count, values| [ label, values.any? ? SolrQuery.field(CLASSIFICATION_FIELD, values) : nil ] }
    places = fetched["places"].to_a.to_h { |value, _count| [ value, "#{PLACE_FIELD}:#{SolrQuery.phrase(value)}" ] }
    periods = periods().to_h { |label, first, last| [ label, period_query(first, last) ] }
    used = fetched.fetch("images", {}).values.map { |image| image[:id].to_s } # no picture is shown twice on the page
    { "kind_images" => kinds, "place_images" => places, "period_images" => periods }.transform_values do |filters|
      filters.filter_map do |label, filter|
        image = filter && example_image(filter, skip: used, viewable: true)
        next unless image

        used << image[:id].to_s
        [ label, image ]
      end.to_h
    end
  rescue StandardError => e
    Rails.logger.warn("Explore link images unavailable: #{e.class}")
    {}
  end

  # The description of each record type, place and period (CardDescription): { "kind_intros" => { label => text }, ... }. A failure costs the
  # descriptions only.
  def self.fetch_link_intros(fetched)
    kinds = fetched["kinds"].to_a.filter_map { |label, _count, values| [ label, { filter: SolrQuery.field(CLASSIFICATION_FIELD, values), kinds: false } ] if values.any? }
    places = fetched["places"].to_a.map { |value, _count| [ value, { filter: "#{PLACE_FIELD}:#{SolrQuery.phrase(value)}" } ] }
    periods = periods().map { |label, first, last| [ label, { filter: period_query(first, last), earliest: first == EARLIEST_YEAR } ] }
    { "kind_intros" => kinds, "place_intros" => places, "period_intros" => periods }.transform_values do |described|
      described.to_h { |label, options| [ label, CardDescription.for(**options) ] }
    end
  rescue StandardError => e
    Rails.logger.warn("Explore descriptions unavailable: #{e.class}")
    {}
  end

  # Links as tiles: the first ROW (record types: those with a picture first, in the list's order), each with its picture if it has one
  def self.link_tiles(links, images, intros = nil, prefer_images: false, limit: ROW)
    images ||= {}
    intros ||= {}
    chosen = prefer_images ? links.select { |link| images[link.label] } + links.reject { |link| images[link.label] } : links
    chosen.first(limit).each_with_index.map do |link, index|
      Tile.new(label: link.label, count: link.count, query: link.query, image: build_image(images[link.label]), tint: ((index + 2) % TINTS) + 1, intro: intros[link.label].presence)
    end
  end

  def self.text_only?(name) = config.dig("collections", "text_only").include?(name)

  # The first record, in id order, that Discovery.pickable? allows (AccessPolicy :open, not Sensitivity.sensitive?) and whose thumbnail
  # is a file this server holds. The Solr filters narrow the search; the Ruby checks decide.
  #
  # viewable: true (the record types, places and periods) takes any record whose thumbnail a result card would show instead (its asset
  # may be seen, AccessPolicy.view?, and it is not sensitive), the thumbnail being the DAM's own (a full address) or a file held here.
  def self.example_image(group_filter, skip: [], viewable: false)
    fq = viewable ? [ "thumbnail_path_ssi:*", "-restrictions_tsi:sensitive", ViewingClassification::EXCLUDE_RESTRICTED, group_filter ] : [ FreeReuse.filter_query, "has_digital_asset_bsi:true", "-restrictions_tsi:sensitive", "{!prefix f=thumbnail_path_ssi}#{THUMBNAIL_DIRECTORY}", group_filter ]
    response = Discovery.search(q: "*:*", sort: "id asc", rows: IMAGE_CANDIDATES, fq: fq)
    response.documents.each do |document|
      next if skip.include?(document.id.to_s)
      next unless viewable ? (AccessPolicy.view?(document) && !Sensitivity.sensitive?(document)) : Discovery.pickable?(document)

      path = document["thumbnail_path_ssi"].to_s
      width, height = ImageDimensions.for_path(path)
      title = Array(document["title_tsim"]).first.to_s.strip.presence || "Untitled record"
      return { id: document.id.to_s, title: title, path: path, width: width, height: height } if viewable && path.present?
      return { id: document.id.to_s, title: title, path: path, width: width, height: height } if width && path.start_with?(THUMBNAIL_DIRECTORY)
    end
    nil
  end

  def self.period_query(first, last) = "#{DATE_FIELD}:[#{first} TO #{last}]"

  # FILM ONLY (private copy for the 2027 showcase clip; never pushed): every University collection as a tile, with the collection
  # thumbnails supplied for the film. No record counts are shown, as most of these collections have no records in this index yet.
  FILM_COLLECTIONS = [
    [ "University Art Collection", "/film-thumbs/00-university-art-collection.jpg", 1200, 600 ],
    [ "Architecture, Building and Planning Library Rare Material Collection", "/film-thumbs/01-architecture-building-and-planning-library-rare-material-collection.jpg", 220, 165 ],
    [ "Archives and Special Collections", "/film-thumbs/02-archives-and-special-collections.jpg", 600, 368 ],
    [ "Burnley Campus Archives", "/film-thumbs/03-burnley-campus-archives.png", 672, 417 ],
    [ "Creswick Campus Historical Collection", "/film-thumbs/04-creswick-campus-historical-collection.jpg", 570, 564 ],
    [ "Dookie Campus Historical Collection", "/film-thumbs/05-dookie-campus-historical-collection.png", 220, 165 ],
    [ "Ed Muirhead Physics Museum", "/film-thumbs/06-ed-muirhead-physics-museum.jpg", 600, 400 ],
    [ "F.A. Singleton Earth Sciences Collection", "/film-thumbs/07-f-a-singleton-earth-sciences-collection.jpg", 600, 389 ],
    [ "Engineering and Information Technology Collection", "/film-thumbs/08-engineering-and-information-technology-collection.jpg", 600, 400 ],
    [ "Godfrey Howitt Entomology Collection", "/film-thumbs/09-godfrey-howitt-entomology-collection.png", 277, 179 ],
    [ "Grainger Museum Collection", "/film-thumbs/10-grainger-museum-collection.jpg", 600, 401 ],
    [ "Harry Brookes Allen Museum of Anatomy and Pathology", "/film-thumbs/11-harry-brookes-allen-museum-of-anatomy-and-pathology.jpg", 600, 300 ],
    [ "Henry Forman Atkinson Dental Museum", "/film-thumbs/12-henry-forman-atkinson-dental-museum.jpg", 600, 300 ],
    [ "International House Collection", "/film-thumbs/13-international-house-collection.jpg", 600, 403 ],
    [ "Law Rare Books Collection", "/film-thumbs/14-law-rare-books-collection.jpg", 400, 300 ],
    [ "Medical History Museum", "/film-thumbs/15-medical-history-museum.jpg", 600, 300 ],
    [ "MONIAC Economics Model Machine", "/film-thumbs/16-moniac-economics-model-machine.png", 343, 216 ],
    [ "Musical Instruments Collection: Rare and Historic Examples", "/film-thumbs/17-musical-instruments-collection-rare-and-historic-examples.jpg", 220, 165 ],
    [ "School of Chemistry Collection", "/film-thumbs/18-school-of-chemistry-collection.jpg", 500, 312 ],
    [ "Southbank Library Special Collections", "/film-thumbs/19-southbank-library-special-collections.png", 457, 354 ],
    [ "Tiegs Zoology Museum", "/film-thumbs/20-tiegs-zoology-museum.jpg", 400, 300 ],
    [ "University of Melbourne Herbarium", "/film-thumbs/21-university-of-melbourne-herbarium.jpg", 600, 215 ],
    [ "Veterinary Science Anatomy Collection", "/film-thumbs/22-veterinary-science-anatomy-collection.png", 220, 165 ],
    [ "Victorian College of the Arts Film and Television Archives", "/film-thumbs/23-victorian-college-of-the-arts-film-and-television-archives.png", 260, 173 ],
    [ "Visual Cultures Resource Centre", "/film-thumbs/24-visual-cultures-resource-centre.jpg", 1200, 403 ]
  ].freeze

  def self.film_tiles
    FILM_COLLECTIONS.each_with_index.map do |(name, path, width, height), index|
      Tile.new(label: name, count: nil, query: BrowseHubs.query(COLLECTION_FIELD, name),
               image: Image.new(id: "film-#{index}", title: name, path: path, width: width, height: height), tint: (index % TINTS) + 1)
    end
  end

  def self.collection_tiles(counts)
    return film_tiles if ENV["FILM_ALL_COLLECTIONS"].present?

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

  private_class_method :fetch_counts, :fetch_images, :fetch_link_images, :fetch_link_intros, :link_tiles, :example_image, :collection_pairs, :collection_tiles, :kind_links, :place_links, :period_links
end
