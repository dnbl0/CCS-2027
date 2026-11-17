# frozen_string_literal: true

module Browse
  # The cards of the Browse page: for each hub (BrowseHubs) the CARDS values with the most records, as two rows of four. A card is a
  # value (an object type, a place, a period, a maker, a subject), its record count and the search that opens every record with it
  # (BrowseHubs.query: the hub's own facet filter, so "Medical device" opens the results with the Medical device object type applied).
  #
  # A card has a picture when a record of the value has a thumbnail that a result card would show (AccessPolicy.view?, not sensitive).
  # Only values with a picture compete for the first places, so the cards that have a picture come first, and no picture is shown twice.
  # The list is kept for a day, and the last good copy for a month, as BrowseHubs does. If Solr cannot answer and nothing is kept, the
  # hub has no cards and its section shows only its heading and its "See all" link.
  module Cards
    CARDS = 8
    # The values looked at when choosing the cards that have a picture, most records first
    CANDIDATES = 60
    PER_VALUE = 20 # records looked at for one value's picture
    Card = Data.define(:label, :count, :query, :image, :intro)

    def self.for(hub)
      kept = cached(hub) { build(hub) }
      return [] if kept.blank?

      kept.map do |entry|
        Card.new(label: entry["label"], count: entry["count"], query: query(hub, entry), image: ExploreEntryPoints.build_image(entry["image"]), intro: intro(hub, entry["count"]))
      end
    end

    # "12 records of this object type": the hub's singular noun, so no description of the value is invented
    def self.intro(hub, count) = I18n.t("browse.cards.intro", count: count, number: ActiveSupport::NumberHelper.number_to_delimited(count), kind: hub.singular)

    def self.query(hub, entry)
      entry["first"] ? BrowseHubs.period_query(entry["first"], entry["last"]) : BrowseHubs.query(hub.field, entry["label"])
    end

    # [{ "label", "count", "image", "first", "last" }, ...]: nil when Solr cannot answer
    def self.build(hub)
      candidates = candidates(hub)
      return if candidates.nil?

      images = images(hub, candidates)
      chosen = candidates.select { |candidate| images[candidate["label"]] } + candidates.reject { |candidate| images[candidate["label"]] }
      chosen.first(CARDS).map { |candidate| candidate.merge("image" => images[candidate["label"]]) }
    end

    def self.candidates(hub)
      if hub.slug == "periods"
        entries = BrowseHubs.period_entries
        entries&.sort_by { |_label, count, _first, _last| -count }&.first(CANDIDATES)&.map { |label, count, first, last| { "label" => label, "count" => count, "first" => first, "last" => last } }
      else
        values = BrowseHubs.values(hub)
        values&.reject { |value, _count| Browse.noise?(value) }&.first(CANDIDATES)&.map { |value, count| { "label" => value, "count" => count.to_i } }
      end
    end

    # { label => image hash }, drawn for the values in order until there are CARDS of them. A value's picture is the first of its
    # records that a result card would show: its asset may be seen (AccessPolicy.view?, so not a withheld one) and it is not sensitive
    # (Sensitivity), so a card never shows more than the same record's card in the results.
    def self.images(hub, candidates)
      found = {}
      used = []
      candidates.each do |candidate|
        break if found.size >= CARDS

        image = example_image(hub, candidate, used)
        next unless image

        used << image[:id]
        found[candidate["label"]] = image
      end
      found
    rescue StandardError => e
      Rails.logger.warn("Browse card pictures unavailable: #{e.class}")
      {}
    end

    def self.example_image(hub, candidate, used)
      group = if candidate["first"]
                ExploreEntryPoints.period_query(candidate["first"], candidate["last"])
      else
                "#{hub.field}:#{Browse.phrase(candidate["label"])}"
      end
      response = Discovery.search(q: "*:*", sort: "id asc", rows: PER_VALUE, fq: [ "thumbnail_path_ssi:*", "-restrictions_tsi:sensitive", group ])
      response.documents.each do |document|
        next if used.include?(document.id.to_s) || !AccessPolicy.view?(document) || Sensitivity.sensitive?(document)

        image = image_of(document)
        return image if image
      end
      nil
    end

    # The picture as the Explore tiles keep it; its size is known only for a thumbnail this server holds (the DAM's are on its own host)
    def self.image_of(document)
      path = document["thumbnail_path_ssi"].to_s
      return if path.blank?

      width, height = ImageDimensions.for_path(path)
      { id: document.id.to_s, title: Array(document["title_tsim"]).first.to_s.strip.presence || "Untitled record", path: path, width: width, height: height }
    end

    def self.cached(hub)
      key = "browse_cards/v1/#{hub.slug}"
      Rails.cache.fetch(SuppressedRecord.cache_key(key), expires_in: 1.day, skip_nil: true) do
        fetched = yield
        Rails.cache.write(SuppressedRecord.cache_key("browse_cards/last_good/v1/#{hub.slug}"), fetched, expires_in: 30.days) if fetched
        fetched
      end || Rails.cache.read(SuppressedRecord.cache_key("browse_cards/last_good/v1/#{hub.slug}"))
    end

    private_class_method :build, :candidates, :images, :example_image, :image_of, :cached
  end
end
