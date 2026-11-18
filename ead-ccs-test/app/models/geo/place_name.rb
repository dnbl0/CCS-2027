# frozen_string_literal: true

module Geo
  # The text sent to the geocoder for a production place, and the key two spellings of one place share
  module PlaceName
    # "[London]" -> "London"; "Europe (?)" -> "Europe"; "Paris?" -> "Paris"
    def self.clean(text)
      text.to_s.tr("[]", "").sub(/\s*\(\?\)\s*\z/, "").sub(/\?+\s*\z/, "").squish
    end

    def self.normalise(text) = clean(text).downcase

    # Values with nothing to look up: "Unknown", "Not specified", blank
    def self.skip?(text) = Browse.noise?(clean(text))
  end
end
