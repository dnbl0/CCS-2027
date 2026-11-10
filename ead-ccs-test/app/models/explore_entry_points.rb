# frozen_string_literal: true

# The home page's "Explore by" section: ways into the records that need no search term, by object type, place and time (the
# entry points Google Arts & Culture and Europeana lead with). Every link opens all the matching records: the any_assets
# marker keeps the default "With a digital asset" filter off (docs/adr/0004).
#
# The values and numbers come from one Solr request, kept for a day, and the last good answer for a month, as BrowseMenu does
# (CCS-147). If Solr cannot answer and nothing is kept, there are no groups and the home page leaves the section out.
#
# Each group may carry one example image (the University's Sublink menu "with images"): a record of the group whose asset anyone may
# download (AccessPolicy :open), that is not sensitive (Sensitivity), whose thumbnail this server holds so its size is known
# (ImageDimensions). It is chosen in the same refresh as the numbers (one more Solr request per group) and kept with them. A group with
# no such record has no image, and the section draws it as text only. Nothing else about a record, and no path of a withheld
# record, is ever kept here.
module ExploreEntryPoints
  Image = Data.define(:id, :title, :path, :width, :height)
  Group = Data.define(:id, :heading, :items, :image) do
    def initialize(id:, heading:, items:, image: nil) = super
  end
  Item = Data.define(:label, :count, :query)

  OBJECT_TYPE_FIELD = "object_type_ssim"
  PLACE_FIELD = "production_place_ssim"
  DATE_FIELD = "date_start_isi"
  LIMIT = 8
  CACHE_KEY = "explore_entry_points/v1"
  LAST_GOOD_KEY = "explore_entry_points/last_good/v1"
  # Records looked at, in id order, for each group's example image
  IMAGE_CANDIDATES = 12
  THUMBNAIL_DIRECTORY = "/digital-assets/thumbs/"
  # BC dates are real (negative years), so the first period has no lower bound worth showing
  EARLIEST_YEAR = -10_000

  # [label, first year, last year]
  def self.periods(this_year = Time.zone.today.year)
    [
      [ "Before 1000", EARLIEST_YEAR, 999 ], [ "1000–1499", 1000, 1499 ], [ "1500–1799", 1500, 1799 ],
      [ "1800–1899", 1800, 1899 ], [ "1900–1999", 1900, 1999 ], [ "2000 onwards", 2000, this_year ]
    ]
  end

  def self.period_key(first, last) = "#{first}-#{last}"

  # counts: as ExploreEntryPoints.counts returns them (empty when Solr is unavailable)
  def self.groups(counts = self.counts)
    return [] if counts.blank?

    images = counts["images"] || {}
    [
      facet_group("object-type", "Object type", OBJECT_TYPE_FIELD, counts[OBJECT_TYPE_FIELD], images["object-type"]),
      facet_group("place", "Place", PLACE_FIELD, counts[PLACE_FIELD], images["place"]),
      period_group(counts["periods"] || {}, images["time"])
    ].select { |group| group.items.any? }
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
        q: "*:*", rows: 0, wt: "json", facet: true, "facet.mincount": 1, "facet.limit": LIMIT, "facet.sort": "count",
        "facet.field": [ OBJECT_TYPE_FIELD, PLACE_FIELD ],
        "facet.query": periods.map { |_label, first, last| period_query(first, last) }
      })
    end
    facets = response.dig("facet_counts", "facet_fields") || {}
    queries = response.dig("facet_counts", "facet_queries") || {}
    fetched = {
      OBJECT_TYPE_FIELD => facets[OBJECT_TYPE_FIELD].to_a.each_slice(2).to_a,
      PLACE_FIELD => facets[PLACE_FIELD].to_a.each_slice(2).to_a,
      "periods" => periods.to_h { |_label, first, last| [ period_key(first, last), queries[period_query(first, last)] ] }
    }
    fetched.merge("images" => fetch_images(fetched))
  rescue RSolr::Error::Http, RSolr::Error::ConnectionRefused, RSolr::Error::Timeout, Faraday::Error, SystemCallError, Timeout::Error => e
    Rails.logger.warn("Explore entry points unavailable: #{e.class}")
    nil
  end

  # { group id => { id:, title:, path: } } for the groups that have an example record. A failure here costs the images, not the numbers.
  def self.fetch_images(counts)
    image_filters(counts).filter_map do |group_id, filter|
      image = example_image(filter)
      [ group_id, image ] if image
    end.to_h
  rescue StandardError => e
    Rails.logger.warn("Explore example images unavailable: #{e.class}")
    {}
  end

  # The Solr filter that says "a record of this group", for each group that has values
  def self.image_filters(counts)
    {
      "object-type" => value_filter(OBJECT_TYPE_FIELD, counts[OBJECT_TYPE_FIELD]),
      "place" => value_filter(PLACE_FIELD, counts[PLACE_FIELD]),
      "time" => counts["periods"].values.sum(&:to_i).positive? ? "#{DATE_FIELD}:[* TO *]" : nil
    }.compact
  end

  def self.value_filter(field, pairs)
    values = pairs.to_a.map(&:first)
    "#{field}:(#{values.map { |value| %("#{value.to_s.gsub(/["\\]/) { |char| "\\#{char}" }}") }.join(' ')})" if values.any?
  end

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

  def self.facet_group(id, heading, field, pairs, image = nil)
    items = pairs.to_a.map { |value, count| Item.new(value, count, BrowseHubs.query(field, value)) }
    Group.new(id: id, heading: heading, items: items, image: build_image(image))
  end

  def self.build_image(image)
    return unless image.is_a?(Hash)

    Image.new(**image.symbolize_keys.slice(*Image.members))
  rescue ArgumentError
    nil
  end

  def self.period_group(counts, image = nil)
    items = periods.filter_map do |label, first, last|
      count = counts[period_key(first, last)].to_i
      next if count.zero?

      Item.new(label, count, BrowseHubs.period_query(first, last))
    end
    Group.new(id: "time", heading: "Time", items: items, image: build_image(image))
  end

  private_class_method :fetch_counts, :fetch_images, :image_filters, :value_filter, :example_image, :facet_group, :build_image, :period_group
end
