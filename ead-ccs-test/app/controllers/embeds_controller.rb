# frozen_string_literal: true

# The embeddable cards: one record (/embed/records/:id) and one shared gallery (/embed/galleries/:token), for another site to
# show in an iframe. They are the only pages that may be framed (EmbedPolicy), so they are a controller of their own: no
# session, no cookie, no header or footer of the site, no script. What they show is what any visitor may see and nothing a
# visitor chose: SharedMedia decides the image, so a withheld or sensitive record shows its notice and no image. Every response
# is noindex (RobotsPolicy lists /embed). A record or gallery that is gone is a 404 inside the frame, not the site's error page,
# which could not be framed.
class EmbedsController < ActionController::Base
  include RecordLookup

  GALLERY_RECORDS = 12 # the records a gallery's embed lists; the rest are behind its link

  layout "embed"

  before_action :allow_framing
  rescue_from ActionController::RoutingError, with: :not_found
  rescue_from Blacklight::Exceptions::ECONNREFUSED, Blacklight::Exceptions::InvalidRequest, Faraday::TimeoutError,
              Faraday::ConnectionFailed, with: :unavailable

  helper_method :site_url

  def record
    @document = find_record(params[:id])
    @record_url = site_url(solr_document_path(@document))
    @image_path = SharedMedia.thumbnail_path(@document)
    @withheld = SharedMedia.withheld_reason(@document)
  end

  def gallery
    @list = Rails.configuration.x.saved_records ? List.find_shared(params[:token]) : nil
    raise ActionController::RoutingError, "Not Found" unless @list

    ids = @list.list_items.recent.limit(GALLERY_RECORDS).pluck(:document_id)
    @total = @list.list_items.count
    @documents = find_records(ids)
    @gallery_url = site_url(gallery_path(@list.share_token))
  end

  private

  # The site's address as the outside world sees it (SEO_CANONICAL_BASE_URL behind a proxy)
  def site_url(path = "/") = "#{BotControls.base_url(request)}#{path}"

  def allow_framing
    response.headers.delete("X-Frame-Options")
    response.headers["Content-Security-Policy"] = EmbedPolicy.content_security_policy
    response.headers["Cache-Control"] = "private, max-age=0, must-revalidate"
  end

  def not_found
    @message = :not_found
    render "embeds/message", status: :not_found
  end

  def unavailable
    @message = :unavailable
    render "embeds/message", status: :service_unavailable
  end
end
