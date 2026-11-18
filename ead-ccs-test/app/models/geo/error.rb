# frozen_string_literal: true

module Geo
  # Geocoding or writing places cannot go on: the index is not configured, or the geocoding service failed
  class Error < StandardError; end
end
