# frozen_string_literal: true

# Stand-ins for Nominatim and Solr in the geocoding tests: no network, no Solr.
module GeoFakes
  # Nominatim's jsonv2 answer for one place
  def nominatim_hit(lat:, lon:, addresstype: "city", name: "Melbourne", **address)
    { "lat" => lat.to_s, "lon" => lon.to_s, "addresstype" => addresstype, "name" => name, "address" => address.transform_keys(&:to_s) }
  end

  # A Nominatim HTTP stand-in: answers { query text => [hits] } (missing: []), or a status; remembers every request
  class Http
    attr_reader :requests

    def initialize(answers = {}, status: 200)
      @answers = answers
      @status = status
      @requests = []
    end

    def call(uri, headers)
      @requests << [ uri, headers ]
      query = URI.decode_www_form(uri.query).to_h["q"]
      [ @status, @answers.fetch(query, []).to_json ]
    end
  end

  # An RSolr client over documents: answers the geocoder's pivot facet and the writer's cursor walk, applies atomic "set" updates
  class Solr
    attr_reader :docs, :adds, :commits, :requests

    def initialize(docs = [], pivot: [])
      @docs = docs.to_h { |doc| [ doc["id"], doc ] }
      @pivot = pivot
      @adds = []
      @commits = 0
      @requests = []
    end

    def get(_path, params:)
      @requests << params
      return { "facet_counts" => { "facet_pivot" => { params[:"facet.pivot"] => @pivot } } } if params[:"facet.pivot"]

      return { "response" => { "docs" => [] }, "nextCursorMark" => params[:cursorMark] } unless params[:cursorMark] == "*"

      matching = @docs.values.select { |doc| doc["production_place_ssim"].present? || doc["geo_digest_ssi"].present? }
      { "response" => { "docs" => matching.map(&:deep_dup) }, "nextCursorMark" => "done" }
    end

    def add(updates)
      @adds << updates
      updates.each do |update|
        doc = @docs.fetch(update["id"])
        update.except("id").each { |field, change| change["set"].nil? ? doc.delete(field) : doc[field] = change["set"] }
      end
    end

    def commit = @commits += 1
  end
end
