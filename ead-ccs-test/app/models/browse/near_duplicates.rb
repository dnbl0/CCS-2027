# frozen_string_literal: true

module Browse
  # Values that say the same thing twice on one page (an entity page's ways in, a collection's groups), so each is shown once:
  #   - spellings of one value: "Île-de-France" and "Ile de France", "London" and "Greater London" (case, accents, punctuation and the
  #     qualifiers below are ignored; the first, which has the most records, is kept)
  #   - a value already shown: the page itself, or a place already among its places ("England, London" as a subject, once London is a
  #     place: a comma-listed subject is matched by its last part)
  #   - on a place's page, the region it is in ("Europe", "Western Europe" on France's page): every record of the place is in it
  module NearDuplicates
    QUALIFIERS = /\b(?:greater|inner|outer|metropolitan|city of)\b/
    COMPASS = /\A(?:western|eastern|northern|southern|central|north|south|east|west)\s+/

    module_function

    def key(name) = I18n.transliterate(name.to_s).downcase.gsub(QUALIFIERS, " ").gsub(/[^a-z0-9]+/, " ").squish

    # pairs: [[value, count]] (a value is a string or anything with #name); shown: names already on the page; region: a place page's region
    def reject(pairs, shown: [], region: nil)
      seen = shown.to_set { |name| key(name) }
      region_key = region && key(region)
      pairs.select do |value, _count|
        name = value.respond_to?(:name) ? value.name : value.to_s
        whole = key(name)
        last = key(name.to_s.split(",").last)
        next false if whole.empty? || seen.include?(whole) || seen.include?(last)
        next false if region_key && whole.sub(COMPASS, "") == region_key

        seen << whole
      end
    end
  end
end
