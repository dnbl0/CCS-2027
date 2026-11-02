# frozen_string_literal: true

# The files for crawlers (CCS-128, CCS-127): /robots.txt, /sitemap.xml with its pages, /llms.txt. Plain ActionController::Base, so no
# session cookie or Blacklight work goes with them. Public and cacheable.
class SeoController < ActionController::Base
  rescue_from Blacklight::Exceptions::ECONNREFUSED, Blacklight::Exceptions::InvalidRequest, Faraday::Error, with: :index_unavailable

  before_action { expires_in 1.hour, public: true }

  def robots
    render plain: RobotsTxt.to_s(BotControls.base_url(request))
  end

  def sitemap_index
    return head(:not_found) unless BotControls.indexing?

    render xml: sitemap.index_xml
  end

  def sitemap_page
    return head(:not_found) unless BotControls.indexing?

    xml = sitemap.page_xml(params[:page].to_i)
    xml ? render(xml: xml) : head(:not_found)
  end

  def llms
    return head(:not_found) unless BotControls.indexing? && BotControls.llms_txt?

    base = BotControls.base_url(request)
    render plain: <<~TEXT, content_type: "text/plain"
      # #{StructuredData::SITE_NAME}

      > #{I18n.t('seo.llms_txt.summary')}

      ## Pages

      - [Search the collections](#{base}/catalog): results, with filters for collection, date and more
      - [Help](#{base}/help): how to search, and how digital assets may be used
      - [About](#{base}/about): what the site is
      - [Sitemap](#{base}/sitemap.xml): every record page

      ## Rights and use

      #{I18n.t('seo.llms_txt.rights')}
    TEXT
  end

  private

  def sitemap = Sitemap.new(base_url: BotControls.base_url(request), records: Sitemap::RecordSource.method(:cached))

  def index_unavailable
    response.headers["Retry-After"] = "300"
    head :service_unavailable
  end
end
