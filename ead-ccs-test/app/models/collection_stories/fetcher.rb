# frozen_string_literal: true

require "net/http"

class CollectionStories
  # Reads one page for the harvest (never at request time). https only, a few redirects on the same scheme, short timeouts, and a
  # plain browser-style User-Agent: unimelb.edu.au sites have refused some fetchers. Anything but a 200 is a FetchError.
  module Fetcher
    USER_AGENT = "Mozilla/5.0 (compatible; CollectionsNavigator-StoriesHarvest/1.0)"
    MAX_REDIRECTS = 3
    TIMEOUT = 15

    module_function

    def call(url, redirects = MAX_REDIRECTS)
      uri = URI(url)
      raise FetchError, "not https: #{url}" unless uri.is_a?(URI::HTTPS)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.get(uri.request_uri, "User-Agent" => USER_AGENT, "Accept" => "text/html")
      end
      case response
      when Net::HTTPSuccess then response.body.to_s.force_encoding(Encoding::UTF_8).scrub
      when Net::HTTPRedirection
        raise FetchError, "too many redirects: #{url}" if redirects.zero?

        call(URI.join(url, response["location"].to_s).to_s, redirects - 1)
      else raise FetchError, "#{response.code} for #{url}"
      end
    rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, URI::Error => e
      raise FetchError, "#{e.class.name} for #{url}: #{e.message}"
    end
  end
end
