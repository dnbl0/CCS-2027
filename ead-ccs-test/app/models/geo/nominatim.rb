# frozen_string_literal: true

require "net/http"

module Geo
  # Looks up one place text with OpenStreetMap Nominatim (https://nominatim.org/release-docs/latest/api/Search/). Its usage policy:
  # at most one request a second, a User-Agent that names the application, results cached (PlaceGeocode keeps them). Only the
  # place text is sent: no record, visitor or personal detail. Used by `rake geo:geocode` on the owner's machine, never by the site.
  class Nominatim
    ENDPOINT = ENV.fetch("GEOCODER_URL", "https://nominatim.openstreetmap.org/search")
    # Names the application, never a person or an email address
    USER_AGENT = ENV.fetch("GEOCODER_USER_AGENT", "CollectionsNavigator-PlaceGeocoder/1.0 (University of Melbourne collections; https://github.com/dnbl0/CCS-2027)")
    INTERVAL = 1.0 # seconds between requests, at least

    Result = Data.define(:lat, :lon, :country, :country_code, :state, :locality, :kind)

    STATE_TYPES = %w[state province region territory state_district county].freeze
    LOCALITY_KEYS = %w[city town village suburb hamlet municipality county island].freeze

    # http: ->(uri, headers) { [status, body] } (tests pass a fake; nothing goes on the network)
    def initialize(http: method(:get), sleeper: ->(seconds) { sleep(seconds) }, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @http = http
      @sleeper = sleeper
      @clock = clock
      @last = nil
    end

    # A Result, or nil when Nominatim knows no such place. Raises Geo::Error when the service fails (nothing is cached then).
    def lookup(text)
      wait
      uri = URI(ENDPOINT)
      uri.query = URI.encode_www_form(q: text, format: "jsonv2", limit: 1, addressdetails: 1, "accept-language": "en")
      status, body = @http.call(uri, { "User-Agent" => USER_AGENT, "Accept" => "application/json" })
      raise Error, "Nominatim answered HTTP #{status}" unless status.to_i == 200

      parse(JSON.parse(body).first)
    rescue JSON::ParserError => e
      raise Error, "Nominatim sent something that is not JSON (#{e.class})"
    end

    def self.parse(hit) = new.send(:parse, hit)

    private

    def wait
      now = @clock.call
      @sleeper.call(INTERVAL - (now - @last)) if @last && now - @last < INTERVAL
      @last = @clock.call
    end

    def parse(hit)
      return nil unless hit.is_a?(Hash) && hit["lat"].present? && hit["lon"].present?

      address = hit["address"] || {}
      type = hit["addresstype"].to_s
      kind = if type == "continent" then "region"
      elsif type == "country" then "country"
      elsif STATE_TYPES.include?(type) && address.key?(type) && type != "county" then "state"
      else "place"
      end
      locality = kind == "place" ? (address.values_at(*LOCALITY_KEYS).compact.first || hit["name"]) : nil
      Result.new(lat: hit["lat"].to_f, lon: hit["lon"].to_f, country: address["country"], country_code: address["country_code"]&.upcase,
                 state: address["state"] || address["province"] || address["territory"], locality: locality, kind: kind)
    end

    def get(uri, headers)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 20) do |http|
        http.get(uri.request_uri, headers)
      end
      [ response.code.to_i, response.body ]
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
      raise Error, "Nominatim could not be reached (#{e.class})"
    end
  end
end
