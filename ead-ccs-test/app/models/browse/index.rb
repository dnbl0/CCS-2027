# frozen_string_literal: true

module Browse
  # Every value of one kind (Kind) with its number of records: one Solr request for the field's facet, cached (CACHE_TTL). The
  # values are grouped by spelling (Slug.fold), so "Portraits" and "portraits" are one entity with two variants; the
  # variant with most records names it.
  #
  # The whole list is read in one request rather than letter by letter (facet.prefix, facet.offset and facet.limit): the biggest
  # field has about 8,000 values (some 300 kB of JSON), the entity pages need the whole list to turn an address back into a
  # value, and a letter's page, the type-to-filter box and the A to Z counts are then all answered from memory. If a field ever
  # grows to hundreds of thousands of values, Index.load is the one place to change (to prefix and offset requests).
  class Index
    Entry = Data.define(:kind_key, :name, :variants, :count, :token, :fold, :letter) do
      def kind = Kind.find(kind_key)
      def slug = Slug.build(kind_key, name)
      def path = Rails.application.routes.url_helpers.browse_entity_path(kind: kind_key, slug: slug)
      def sort_key = Index.sort_key(name)
      def fq = Browse.field_query(kind.field, variants)
      def search_query = Browse.search_query(kind.field, variants)
    end

    # The letters of the A to Z bar, and the group for values that start with a digit or a symbol
    LETTERS = [ *"A".."Z", "0-9" ].freeze

    attr_reader :kind, :entries

    def self.for(kind, repository: nil)
      kind = Kind.find(kind) unless kind.is_a?(Kind)
      entries = Rails.cache.fetch("browse/index/v1/#{kind.key}", expires_in: CACHE_TTL, skip_nil: true) do
        group(kind, load(kind, repository || Blacklight.default_index))
      end
      new(kind, entries)
    end

    # [[value, count], ...] from Solr
    def self.load(kind, repository)
      response = repository.search(params: { q: "*:*", rows: 0, facet: true, "facet.field": kind.field, "facet.limit": -1, "facet.mincount": 1,
                                             "facet.sort": "count", "json.nl": "map", qt: "select", defType: "lucene" })
      Browse::Facets.pairs(response, kind.field)
    end

    def self.sort_key(name)
      key = I18n.transliterate(name.to_s).downcase.sub(/\A[^a-z0-9]+/, "")
      key.presence || name.to_s.downcase
    end

    def self.letter(name)
      first = sort_key(name)[0].to_s
      first.match?(/[a-z]/) ? first.upcase : "0-9"
    end

    # Entries from [[value, count], ...]: grouped by spelling, noise left out, in A to Z order. This is what is cached.
    def self.group(kind, rows)
      rows.reject { |value, _| Browse.noise?(value) }.group_by { |value, _| Slug.fold(value) }.values.map do |members|
        name = members.max_by { |value, count| [ count, -value.length ] }.first
        Entry.new(kind.key, name, members.map(&:first).sort, members.sum { |_, count| count }, Slug.token(kind.key, name), Slug.fold(name), letter(name))
      end.sort_by(&:sort_key)
    end

    def initialize(kind, entries)
      @kind = kind
      @entries = entries
      @by_token = entries.group_by(&:token)
    end

    def size = entries.size
    def total_records = entries.sum(&:count)

    # The entry for a value as a record spells it (nil for noise or a value not in the list)
    def find_value(value)
      return if Browse.noise?(value)

      @by_token[Slug.token(kind.key, value)]&.find { |entry| entry.fold == Slug.fold(value) }
    end

    # What the address names: [entry, canonical?]. The hash decides; a different readable part is a stale address.
    def find_by_slug(slug)
      readable, token = Slug.parse(slug)
      return unless token

      candidates = @by_token[token] || []
      entry = candidates.find { |candidate| Slug.readable(candidate.name) == readable } || candidates.first
      [ entry, entry && entry.slug == slug ] if entry
    end

    def top(limit) = entries.max_by(limit) { |entry| [ entry.count, entry.name ] }

    # One page of the A to Z list. filter: words typed in the box (matched anywhere in the name, ignoring case and accents);
    # letter: one of LETTERS or nil. The letter counts are of the filtered list, so the bar only offers letters with results.
    Page = Data.define(:entries, :total, :page, :pages, :letter, :filter, :letter_counts)

    def page(letter: nil, filter: nil, page: 1, per: HUB_PAGE_SIZE)
      words = Slug.fold(filter.to_s) if filter.present?
      matching = words ? entries.select { |entry| entry.fold.include?(words) } : entries
      counts = matching.group_by(&:letter).transform_values(&:size)
      letter = nil unless LETTERS.include?(letter.to_s)
      shown = letter ? matching.select { |entry| entry.letter == letter } : matching
      pages = [ (shown.size.to_f / per).ceil, 1 ].max
      page = page.to_i.clamp(1, pages)
      Page.new(shown.slice((page - 1) * per, per) || [], shown.size, page, pages, letter, filter.to_s.squish.presence, counts)
    end
  end
end
