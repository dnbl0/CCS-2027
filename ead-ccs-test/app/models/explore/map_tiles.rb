# frozen_string_literal: true

module Explore
  # Where the map's tiles come from (docs/time-and-place.md). The visitor's browser asks this host for them, and only after the
  # visitor presses "Show the map": nothing is asked of it before. The host is added to the Content Security Policy by name.
  # The default is the OpenStreetMap Foundation's server, whose usage policy suits light use only; production should name a
  # tile service the University has an agreement with (MAP_TILE_URL, MAP_TILE_ATTRIBUTION).
  module MapTiles
    DEFAULT_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
    DEFAULT_ATTRIBUTION = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'

    def self.url = ENV.fetch("MAP_TILE_URL", DEFAULT_URL).presence || DEFAULT_URL

    # HTML (the tile provider's own required credit), shown on the map and under it
    def self.attribution = ENV.fetch("MAP_TILE_ATTRIBUTION", DEFAULT_ATTRIBUTION).presence || DEFAULT_ATTRIBUTION

    # "https://tile.openstreetmap.org", for the Content Security Policy; subdomain placeholders ({s}) become a wildcard
    def self.origin
      uri = URI(url.gsub(/\{[a-z]\}\./, "x.").gsub(/\{[^}]*\}/, "0"))
      host = url.match?(%r{//\{[a-z]\}\.}) ? "*.#{uri.host.delete_prefix('x.')}" : uri.host
      "#{uri.scheme}://#{host}"
    end
  end
end
