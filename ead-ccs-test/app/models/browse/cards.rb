# frozen_string_literal: true

module Browse
  # The cards of the Browse page: for each hub (BrowseHubs) eight values, as two rows of four. A card is a value (an object type, a place,
  # a period, a maker, a subject), a picture of one of its records, a short description and the search that opens every record with it
  # (BrowseHubs.query: the hub's own facet filter, so "Medical device" opens the results with the Medical device object type applied).
  #
  # The values are found with the index's own facets (as Blacklight's facet fields are): the facet counts only the records that have a
  # thumbnail and are not sensitive, so every value offered has something to show, and the values with the most such records come first.
  # A value whose pictures a result card would not show (AccessPolicy.view?) is passed over for the next, so every card has a picture
  # while the index has enough values that do; no picture is shown twice. The description is worked out from the value's own records (the
  # kinds of record and the collections that hold most of them), so nothing is written by hand and nothing is invented. Wording is a
  # placeholder: the collections team has not approved it. The cards are kept for a day, and the last good copy for a month, as BrowseHubs.
  module Cards
    CARDS = 8
    CACHE_KEY = "browse_cards/v3"
    LAST_GOOD_KEY = "browse_cards/last_good/v3"
    # The values looked at, most records with a thumbnail first
    CANDIDATES = 40
    PER_VALUE = 20 # records looked at for one value's picture
    THUMBNAIL_FILTERS = [ "thumbnail_path_ssi:*", "-restrictions_tsi:sensitive", ViewingClassification::EXCLUDE_RESTRICTED ].freeze
    # Object types: the cards use the Classification facet (art and design, paintings, ceramics), as the home page's Record types do. Most
    # Object Type values (equipment, photographic medium, instruments) belong to records whose assets are withheld, so they have no
    # picture to show; the "See all" list still lists every Object Type.
    CARD_FIELDS = { "object-types" => ExploreEntryPoints::CLASSIFICATION_FIELD }.freeze
    # Values that are not offered as a card (the Indigenous subjects wait for cultural review, as the Indigenous Collections tile does)
    SKIPPED = { "subjects" => [ "Aboriginal and Torres Strait Islander art", "By Indigenous People", "About Indigenous People" ] }.freeze
    # How each hub's cards are laid out (NexusCcs::CardLayoutComponent): a different shape for each section, so the page is not one grid
    LAYOUT_BY_HUB = { "object-types" => :bento, "places" => :rail, "periods" => :strip, "makers" => :grid, "subjects" => :wall }.freeze
    # path: the value's own page (a place, maker or subject; a period), nil where there is none (object types: the search)
    Card = Data.define(:label, :count, :query, :image, :intro, :path)

    def self.for(hub)
      kept = cached(hub) { build(hub) }
      return [] if kept.blank?

      kept.map do |entry|
        Card.new(label: entry["label"].to_s.upcase_first, count: entry["count"], query: query(hub, entry), image: ExploreEntryPoints.build_image(entry["image"]), intro: entry["intro"],
                 path: path(hub, entry))
      end
    end

    def self.periods?(hub) = hub.slug == "periods"

    def self.path(hub, entry)
      return Browse::Periods.for_span(entry["first"], entry["last"])&.path if entry["first"]

      Browse.path_for(hub.slug, entry["label"]) if Browse::Kind.find(hub.slug)
    end

    def self.field(hub) = CARD_FIELDS.fetch(hub.slug, hub.field)

    def self.query(hub, entry)
      entry["first"] ? BrowseHubs.period_query(entry["first"], entry["last"]) : BrowseHubs.query(field(hub), entry["label"])
    end

    # [{ "label", "count", "image", "intro", "first", "last" }, ...]; nil when Solr cannot answer
    # count: how many cards; describe: false leaves out the line under each (the Places page's wall shows only the name and count)
    def self.build(hub, count: CARDS, describe: true)
      candidates = candidates(hub, limit: [ CANDIDATES, count * 2 ].max)
      return if candidates.nil?

      used = []
      cards = candidates.each_with_object([]) do |candidate, chosen|
        break chosen if chosen.size >= count

        image = example_image(hub, candidate, used)
        next unless image

        used << image[:id]
        chosen << candidate.merge("image" => image, "intro" => (describe(hub, candidate) if describe))
      end
      periods?(hub) ? cards.sort_by { |card| card["first"] } : cards
    rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable => e
      Rails.logger.warn("Browse cards unavailable: #{e.class}")
      nil
    end

    # The values that have records with a thumbnail, most first, from one facet request
    def self.candidates(hub, limit: CANDIDATES)
      if periods?(hub)
        list = BrowseHubs.periods
        response = Discovery.search(q: "*:*", rows: 0, facet: true, fq: THUMBNAIL_FILTERS, "facet.query": list.map { |_label, first, last| ExploreEntryPoints.period_query(first, last) })
        found = response.dig("facet_counts", "facet_queries") || {}
        list.filter_map do |label, first, last|
          count = found[ExploreEntryPoints.period_query(first, last)].to_i
          { "label" => label, "count" => count, "first" => first, "last" => last } if count.positive?
        end.sort_by { |candidate| -candidate["count"] }.first(limit)
      else
        response = Discovery.search(q: "*:*", rows: 0, facet: true, fq: THUMBNAIL_FILTERS, "facet.field": field(hub), "facet.limit": limit * 2, "facet.mincount": 1, "facet.sort": "count")
        pairs = response.dig("facet_counts", "facet_fields", field(hub)).to_a.each_slice(2).to_a
        pairs.reject { |value, _count| Browse.noise?(value) || SKIPPED.fetch(hub.slug, []).include?(value) }.first(limit).map { |value, count| { "label" => value, "count" => count.to_i } }
      end
    end

    def self.group_filter(hub, candidate)
      candidate["first"] ? ExploreEntryPoints.period_query(candidate["first"], candidate["last"]) : "#{field(hub)}:#{Browse.phrase(candidate["label"])}"
    end

    # The first record, in id order, that a result card would show a picture for: its asset may be seen (AccessPolicy.view?, so not a
    # withheld one) and it is not sensitive (Sensitivity). The picture is as the Explore tiles keep it; its size is known only for a thumbnail
    # this server holds (the DAM's are on its own host).
    def self.example_image(hub, candidate, used)
      response = Discovery.search(q: "*:*", sort: "id asc", rows: PER_VALUE, fq: THUMBNAIL_FILTERS + [ group_filter(hub, candidate) ])
      response.documents.each do |document|
        next if used.include?(document.id.to_s) || !AccessPolicy.view?(document) || Sensitivity.sensitive?(document)

        path = document["thumbnail_path_ssi"].to_s
        next if path.blank?

        width, height = ImageDimensions.for_path(path)
        return { id: document.id.to_s, title: Array(document["title_tsim"]).first.to_s.strip.presence || "Untitled record", path: path, width: width, height: height }
      end
      nil
    end

    # One facet request for the card's records (CardDescription): the kinds of record (not for a kind itself) and the collections
    def self.describe(hub, candidate)
      CardDescription.for(filter: group_filter(hub, candidate), kinds: hub.slug != "object-types", earliest: candidate["first"] == ExploreEntryPoints::EARLIEST_YEAR)
    end

    # A Browse page's picture wall (after Google Arts & Culture's Places): the WALL values with the most pictured records (every period,
    # in order), each with one picture, kept for a day as the cards are
    WALL = 48
    def self.wall(hub)
      kept = cached(hub, "wall/v2") { with_totals(hub, build(hub, count: WALL, describe: false)) }
      return [] if kept.blank?

      kept.map do |entry|
        Card.new(label: entry["label"].to_s.upcase_first, count: entry["total"] || entry["count"], query: query(hub, entry), image: ExploreEntryPoints.build_image(entry["image"]), intro: nil,
                 path: path(hub, entry))
      end
    end

    # Each wall card's number of records: every record with the value, not only those with a picture (the cards are found among the
    # pictured ones), from one facet request, so the wall says what the list and the search say
    def self.with_totals(hub, cards)
      return cards if cards.blank?

      totals = if periods?(hub)
        queries = cards.map { |card| ExploreEntryPoints.period_query(card["first"], card["last"]) }
        found = Discovery.search(q: "*:*", rows: 0, facet: true, "facet.query": queries).dig("facet_counts", "facet_queries") || {}
        cards.zip(queries).to_h { |card, query| [ card["label"], found[query] ] }
      else
        pairs = Discovery.search(q: "*:*", rows: 0, facet: true, "facet.field": field(hub), "facet.limit": -1, "facet.mincount": 1)
                         .dig("facet_counts", "facet_fields", field(hub)).to_a.each_slice(2).to_h
        cards.to_h { |card| [ card["label"], pairs[card["label"]] ] }
      end
      cards.map { |card| totals[card["label"]] ? card.merge("total" => totals[card["label"]].to_i) : card }
    rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable
      cards
    end

    def self.cached(hub, kind = nil)
      key = SuppressedRecord.cache_key([ CACHE_KEY, hub.slug, kind ].compact.join("/"))
      last_good = SuppressedRecord.cache_key([ LAST_GOOD_KEY, hub.slug, kind ].compact.join("/"))
      # race_condition_ttl: when the day is up one request builds the cards while the others are still given the old ones
      Rails.cache.fetch(key, expires_in: 1.day, race_condition_ttl: 30.seconds, skip_nil: true) do
        fetched = yield
        Rails.cache.write(last_good, fetched, expires_in: 30.days) if fetched
        fetched
      end || Rails.cache.read(last_good)
    end

    # Builds the cards of every hub now (rake browse:warm_cards), so no visitor waits for the first build of the day
    def self.warm
      BrowseHubs.all.each { |hub| self.for(hub) }
      BrowseHubs.all.each { |hub| wall(hub) }
    end

    private_class_method :build, :periods?, :field, :candidates, :group_filter, :example_image, :describe, :cached
  end
end
