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
    # The values looked at, most records with a thumbnail first
    CANDIDATES = 80
    PER_VALUE = 20 # records looked at for one value's picture
    THUMBNAIL_FILTERS = [ "thumbnail_path_ssi:*", "-restrictions_tsi:sensitive" ].freeze
    # Object types: the cards use the Classification facet (art and design, paintings, ceramics), as the home page's Record types do. Most
    # Object Type values (equipment, photographic medium, instruments) belong to records whose assets are withheld, so they have no
    # picture to show; the "See all" list still lists every Object Type.
    CARD_FIELDS = { "object-types" => ExploreEntryPoints::CLASSIFICATION_FIELD }.freeze
    # Values that are not offered as a card (the Indigenous subjects wait for cultural review, as the Indigenous Collections tile does)
    SKIPPED = { "subjects" => [ "Aboriginal and Torres Strait Islander art", "By Indigenous People", "About Indigenous People" ] }.freeze
    Card = Data.define(:label, :count, :query, :image, :intro)

    def self.for(hub)
      kept = cached(hub) { build(hub) }
      return [] if kept.blank?

      kept.map do |entry|
        Card.new(label: entry["label"].to_s.upcase_first, count: entry["count"], query: query(hub, entry), image: ExploreEntryPoints.build_image(entry["image"]), intro: entry["intro"])
      end
    end

    def self.field(hub) = CARD_FIELDS.fetch(hub.slug, hub.field)

    def self.query(hub, entry)
      entry["first"] ? BrowseHubs.period_query(entry["first"], entry["last"]) : BrowseHubs.query(field(hub), entry["label"])
    end

    # [{ "label", "count", "image", "intro", "first", "last" }, ...]; nil when Solr cannot answer
    def self.build(hub)
      candidates = candidates(hub)
      return if candidates.nil?

      used = []
      cards = candidates.each_with_object([]) do |candidate, chosen|
        break chosen if chosen.size >= CARDS

        image = example_image(hub, candidate, used)
        next unless image

        used << image[:id]
        chosen << candidate.merge("image" => image, "intro" => describe(hub, candidate))
      end
      hub.slug == "periods" ? cards.sort_by { |card| card["first"] } : cards
    rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable => e
      Rails.logger.warn("Browse cards unavailable: #{e.class}")
      nil
    end

    # The values that have records with a thumbnail, most first, from one facet request
    def self.candidates(hub)
      if hub.slug == "periods"
        list = BrowseHubs.periods
        response = Discovery.search(q: "*:*", rows: 0, facet: true, fq: THUMBNAIL_FILTERS, "facet.query": list.map { |_label, first, last| ExploreEntryPoints.period_query(first, last) })
        found = response.dig("facet_counts", "facet_queries") || {}
        list.filter_map do |label, first, last|
          count = found[ExploreEntryPoints.period_query(first, last)].to_i
          { "label" => label, "count" => count, "first" => first, "last" => last } if count.positive?
        end.sort_by { |candidate| -candidate["count"] }.first(CANDIDATES)
      else
        response = Discovery.search(q: "*:*", rows: 0, facet: true, fq: THUMBNAIL_FILTERS, "facet.field": field(hub), "facet.limit": CANDIDATES * 2, "facet.mincount": 1, "facet.sort": "count")
        pairs = response.dig("facet_counts", "facet_fields", field(hub)).to_a.each_slice(2).to_a
        pairs.reject { |value, _count| Browse.noise?(value) || SKIPPED.fetch(hub.slug, []).include?(value) }.first(CANDIDATES).map { |value, count| { "label" => value, "count" => count.to_i } }
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

    # "Includes photographs, letters. Held in the Grainger Museum Collection and the University Art Collection." One facet request
    # for the value's records: the kinds of record (not for a kind itself) and the collections that hold most of them. A
    # period that reaches back before the records' own dates says so.
    def self.describe(hub, candidate)
      kinds_field = hub.slug == "object-types" ? nil : ExploreEntryPoints::CLASSIFICATION_FIELD
      fields = [ kinds_field, ExploreEntryPoints::COLLECTION_FIELD ].compact
      response = Discovery.search(q: "*:*", rows: 0, facet: true, fq: [ group_filter(hub, candidate) ], "facet.field": fields, "facet.limit": 4, "facet.mincount": 1, "facet.sort": "count")
      facets = response.dig("facet_counts", "facet_fields") || {}
      kinds = kinds_field ? top(facets[kinds_field], 2).map(&:downcase) : []
      collections = top(facets[ExploreEntryPoints::COLLECTION_FIELD], 2)
      parts = []
      parts << I18n.t("browse.cards.before") if candidate["first"] == ExploreEntryPoints::EARLIEST_YEAR
      parts << I18n.t("browse.cards.includes", kinds: kinds.join(", ")) if kinds.any?
      parts << I18n.t("browse.cards.held_in", collections: collections.to_sentence) if collections.any?
      parts.join(" ")
    rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable
      ""
    end

    def self.top(pairs, limit) = pairs.to_a.each_slice(2).map(&:first).reject { |value| Browse.noise?(value) || value == "[other]" }.first(limit)

    def self.cached(hub)
      key = "browse_cards/v3/#{hub.slug}"
      Rails.cache.fetch(SuppressedRecord.cache_key(key), expires_in: 1.day, skip_nil: true) do
        fetched = yield
        Rails.cache.write(SuppressedRecord.cache_key("browse_cards/last_good/v3/#{hub.slug}"), fetched, expires_in: 30.days) if fetched
        fetched
      end || Rails.cache.read(SuppressedRecord.cache_key("browse_cards/last_good/v3/#{hub.slug}"))
    end

    private_class_method :build, :field, :candidates, :group_filter, :example_image, :describe, :top, :cached
  end
end
