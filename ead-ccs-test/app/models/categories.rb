# frozen_string_literal: true

# The category picture pages (/browse/categories, docs/categories-themes-stories.md): one page for each way of grouping the records
# (object type, classification, materials, region, era, collection, named collection) with a card for every value: a picture of one of
# its records, the value and its record count, opening the search with that value as a filter (BrowseHubs.query, so the list itself is
# Blacklight's results page).
#
# ONE Solr request a page: the facet counts over every record (the picture filter is excluded from the facet with a tag), and in the same
# answer the first records with a thumbnail, from which each value takes the first picture a result card would show (AccessPolicy.view?,
# not Sensitivity.sensitive?), no picture twice. Kept for a day and the last good copy for a month, as BrowseHubs is. A value no listed
# record has a picture for is a card with no picture (the card's designed face).
module Categories
  Dimension = Data.define(:slug, :field) do
    def title = I18n.t("nexus_ccs.categories.dimensions.#{slug}.title")
    def intro = I18n.t("nexus_ccs.categories.dimensions.#{slug}.intro")
    def path = Rails.application.routes.url_helpers.category_path(slug)
    # The collection and named collection values also have a page of their own (CollectionLandingsController)
    def landing? = %w[collections named-collections].include?(slug)
  end

  # What a card needs (NexusCcs::CardLayoutComponent): the label carries the count, so a narrow card that leaves its description out
  # still shows it
  Tile = Data.define(:label, :value, :count, :query, :image, :intro)
  Page = Data.define(:tiles, :page, :pages, :sort, :total)

  DIMENSIONS = [
    Dimension.new("object-types", "object_type_ssim"),
    Dimension.new("classifications", "classification_ssim"),
    Dimension.new("materials", "material_ssim"),
    Dimension.new("regions", "region_ssim"),
    Dimension.new("eras", "date_era_ssim"),
    Dimension.new("collections", "collection_ssim"),
    Dimension.new("named-collections", "named_collection_ssim")
  ].freeze

  PER_PAGE = 48
  SORTS = %w[count az].freeze
  IMAGE_ROWS = 1000 # records with a thumbnail read for the pictures; values beyond them get a card with no picture
  IMAGE_TAG = "img"
  IMAGE_FILTERS = [ "{!tag=#{IMAGE_TAG}}thumbnail_path_ssi:*", "{!tag=#{IMAGE_TAG}}-restrictions_tsi:sensitive" ].freeze
  FIELDS = %w[id title_tsim thumbnail_path_ssi licence_type_ssim digital_asset_metadata_ssm access_condition_ssi restrictions_tsi].freeze

  def self.all = DIMENSIONS

  def self.find(slug) = DIMENSIONS.find { |dimension| dimension.slug == slug.to_s }

  # [{ "value", "count", "image" }, ...], most records first; nil when Solr cannot answer and nothing is kept
  def self.values(dimension)
    key = "categories/v1/#{dimension.slug}"
    Rails.cache.fetch(SuppressedRecord.cache_key(key), expires_in: 1.day, skip_nil: true) do
      fetched = fetch(dimension)
      Rails.cache.write(SuppressedRecord.cache_key("categories/last_good/v1/#{dimension.slug}"), fetched, expires_in: 30.days) if fetched
      fetched
    end || Rails.cache.read(SuppressedRecord.cache_key("categories/last_good/v1/#{dimension.slug}"))
  end

  # One page of cards; sort is "count" (most records first) or "az"
  def self.page(dimension, sort: "count", page: 1)
    rows = values(dimension)
    return if rows.nil?

    sort = SORTS.include?(sort.to_s) ? sort.to_s : "count"
    rows = rows.sort_by { |row| I18n.transliterate(row["value"].to_s).downcase } if sort == "az"
    pages = [ (rows.size.to_f / PER_PAGE).ceil, 1 ].max
    page = page.to_i.clamp(1, pages)
    tiles = rows.slice((page - 1) * PER_PAGE, PER_PAGE).to_a.map { |row| tile(dimension, row) }
    Page.new(tiles: tiles, page: page, pages: pages, sort: sort, total: rows.size)
  end

  def self.tile(dimension, row)
    count = ActiveSupport::NumberHelper.number_to_delimited(row["count"])
    image = ExploreEntryPoints.build_image(row["image"]) unless ExploreEntryPoints.text_only?(row["value"])
    Tile.new(label: "#{row['value'].to_s.upcase_first} (#{count})", value: row["value"], count: row["count"],
             query: BrowseHubs.query(dimension.field, row["value"]), image: image, intro: nil)
  end

  # The value of a dimension whose page address (Browse::Slug) has this token, or nil
  def self.value_for_slug(dimension, slug)
    _readable, token = Browse::Slug.parse(slug)
    return unless token

    values(dimension).to_a.map { |row| row["value"] }.find { |value| Browse::Slug.token(dimension.slug, value) == token }
  end

  def self.fetch(dimension)
    response = SolrGuard.run do
      Discovery.search(q: "*:*", rows: IMAGE_ROWS, sort: "id asc", fl: (FIELDS + [ dimension.field ]).join(","), fq: IMAGE_FILTERS, facet: true,
                       "facet.field": "{!ex=#{IMAGE_TAG}}#{dimension.field}", "facet.limit": -1, "facet.mincount": 1, "facet.sort": "count")
    end
    pairs = response.dig("facet_counts", "facet_fields", dimension.field).to_a
    pairs = pairs.each_slice(2).to_a unless pairs.first.is_a?(Array)
    images = images_by_value(response.documents, dimension.field)
    pairs.reject { |value, _| Browse.noise?(value) }.map { |value, count| { "value" => value, "count" => count.to_i, "image" => images[value] } }
  rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable => e
    Rails.logger.warn("Categories unavailable: #{e.class}")
    nil
  end

  # { value => image hash }: each record that a result card would show a picture for gives it to the first of its values that has none
  def self.images_by_value(documents, field)
    documents.each_with_object({}) do |document, images|
      next unless AccessPolicy.view?(document) && !Sensitivity.sensitive?(document)

      path = document["thumbnail_path_ssi"].to_s
      value = Array(document[field]).find { |candidate| !images.key?(candidate) }
      next if path.blank? || value.nil?

      width, height = ImageDimensions.for_path(path)
      images[value] = { "id" => document.id.to_s, "title" => Array(document["title_tsim"]).first.to_s.strip.presence || "Untitled record",
                        "path" => path, "width" => width, "height" => height }
    end
  end

  private_class_method :fetch, :images_by_value, :tile
end
