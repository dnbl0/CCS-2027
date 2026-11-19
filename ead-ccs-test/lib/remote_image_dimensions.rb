# frozen_string_literal: true

require "net/http"

# Width and height of a record's image held by the DAM, for the IIIF manifest (IiifManifest: a canvas must have a size, CCS-57). The
# DAM's images are not files on this server, so ImageDimensions cannot read them: the first 64 KB of the file are asked for (a Range
# request, enough for a JPEG's or PNG's header) and read the same way. Only https links on the allowed image hosts (the same list as
# Colour::Fetcher, COLOUR_IMAGE_HOSTS, default unimelbourne.widen.net) are asked; anything else gives nil and nothing is requested.
# Redirects are not followed. A size, once read, is kept in the Rails cache for 30 days; a failure is not kept, so it is asked again
# next time. Never called while a record page is drawn: the page reads only the kept size (.cached).
module RemoteImageDimensions
  RANGE = 65_535
  KEEP = 30.days

  module_function

  # [width, height] or nil
  def for_url(url, hosts: Colour::Fetcher.hosts, cache: Rails.cache, get: method(:http_get))
    uri = allowed_uri(url, hosts) or return
    kept = cache.read(key(uri))
    return kept if kept

    body = get.call(uri) or return
    size = ImageDimensions.from_io(StringIO.new(body.b))
    cache.write(key(uri), size, expires_in: KEEP) if size
    size
  rescue StandardError => error
    Rails.logger.warn("[remote_image_dimensions] #{error.class}: #{error.message}")
    nil
  end

  # The kept size, without asking the DAM (nil when it has not been read yet)
  def cached(url, hosts: Colour::Fetcher.hosts, cache: Rails.cache)
    uri = allowed_uri(url, hosts) or return
    cache.read(key(uri))
  end

  def allowed_uri(url, hosts)
    uri = URI.parse(url.to_s)
    uri if uri.is_a?(URI::HTTPS) && hosts.include?(uri.host) && uri.userinfo.nil? && uri.port == 443
  rescue URI::InvalidURIError
    nil
  end

  def key(uri) = "remote-image-dimensions/#{Digest::SHA256.hexdigest(uri.to_s)}"

  # The first RANGE + 1 bytes, or nil (a refusal, a redirect, an error page)
  def http_get(uri)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 5) do |http|
      response = http.request(Net::HTTP::Get.new(uri, "Range" => "bytes=0-#{RANGE}", "User-Agent" => "CollectionsNavigator-iiif/1.0"))
      response.body&.byteslice(0, RANGE + 1) if response.is_a?(Net::HTTPSuccess)
    end
  end
end
