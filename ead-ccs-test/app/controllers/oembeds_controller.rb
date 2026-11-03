# frozen_string_literal: true

# oEmbed 1.0 (https://oembed.com): a consumer that has the address of a record or a shared gallery asks here for the iframe that
# embeds it. JSON only. Tier-safe for the same reason the embed pages are: the thumbnail is given only where SharedMedia allows,
# and a gallery's response names the gallery and nothing about who made it. Anything that is not an address of this site's record
# or gallery is a 404; an address of a gallery whose link was revoked is too.
class OembedsController < ActionController::Base
  include RecordLookup

  RECORD_PATH = %r{\A/catalog/([^/]+)\z}
  GALLERY_PATH = %r{\A/galleries/([A-Za-z0-9_-]{32})\z}

  rescue_from ActionController::RoutingError do
    head :not_found
  end
  rescue_from Blacklight::Exceptions::ECONNREFUSED, Blacklight::Exceptions::InvalidRequest, Faraday::TimeoutError,
              Faraday::ConnectionFailed do
    head :service_unavailable
  end

  def show
    return head :not_implemented unless %w[json].include?(params[:format].presence || "json")

    path = site_path(params[:url])
    raise ActionController::RoutingError, "Not Found" unless path

    response.headers["Access-Control-Allow-Origin"] = "*" # public data, no credentials
    response.headers["Cache-Control"] = "private, max-age=0, must-revalidate"
    render json: (record_payload(path[RECORD_PATH, 1]) if path.match?(RECORD_PATH)) || gallery_payload(path[GALLERY_PATH, 1]),
           content_type: "application/json"
  end

  private

  def base = BotControls.base_url(request)

  # The path of an address on this site, or nil
  def site_path(address)
    return if address.blank? || address.length > 2048

    uri = URI.parse(address.to_s)
    host = URI.parse(base).host
    return unless uri.is_a?(URI::HTTP) && [ host, request.host ].include?(uri.host)

    uri.path.to_s.chomp("/")
  rescue URI::InvalidURIError
    nil
  end

  def record_payload(id)
    document = find_record(CGI.unescape(id))
    code = EmbedCode.for_record(document, src: "#{base}#{embed_record_path(document.id)}").fitted(**limits)
    payload(code, title: Array(document["title_tsim"]).first.presence || "Untitled").tap do |data|
      thumb = SharedMedia.thumbnail_path(document)
      data[:thumbnail_url] = "#{base}#{thumb}" if thumb
    end
  end

  def gallery_payload(token)
    list = Rails.configuration.x.saved_records ? List.find_shared(token) : nil
    raise ActionController::RoutingError, "Not Found" unless list

    code = EmbedCode.for_gallery(list, src: "#{base}#{embed_gallery_path(list.share_token)}").fitted(**limits)
    payload(code, title: list.name)
  end

  def payload(code, title:)
    { version: "1.0", type: "rich", title: title, provider_name: EmbedCode::PROVIDER, provider_url: "#{base}/",
      cache_age: 300, width: code.width, height: code.height, html: code.fixed }
  end

  def limits = { max_width: params[:maxwidth], max_height: params[:maxheight] }
end
