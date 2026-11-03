# frozen_string_literal: true

# What a page tells search engines, social networks and AI crawlers about itself (CCS-128, CCS-127): the meta description, the
# canonical link, the robots directive, the Open Graph and Twitter card tags, and the JSON-LD. layouts/_seo_head draws it; the
# rules live in CanonicalUrl, RobotsPolicy and StructuredData. The page's <title> is the page's own and is not set here.
#
#   page type    description                       canonical                      JSON-LD
#   home         config/locales/seo.en.yml         /                              WebSite with SearchAction
#   help/about   as above                          the page
#   advanced     as above                          /catalog/advanced
#   results      the search words or collection    /catalog + what changes results
#   record       the record's description          /catalog/:id                   CreativeWork or VisualArtwork
#   stock        the record's (a comparison copy)  /catalog/:id (noindex)
#
# No image, and a general description, for a record the policy withholds or that is sensitive.
class PageMeta
  # The path's first segment => the key in seo.description; any other page is described as About
  PAGE_DESCRIPTIONS = { "accessibility" => "accessibility", "privacy" => "privacy", "help" => "help", "language-in-our-records" => "language", "discover" => "discover" }.freeze

  attr_reader :canonical_url, :robots, :description, :title, :og_image, :json_ld

  # controller/action: from the request; path/params: the request path and query parameters; document: on a record page
  def initialize(controller:, action:, path:, params:, base_url:, title:, document: nil)
    @type = type_of(controller, action)
    @path = path.to_s
    @title = title.to_s
    @document = document if %i[record stock].include?(@type)
    @canonical_url = canonical_for(base_url, path, params)
    @robots = RobotsPolicy.directive(path, params, document: @document)
    @description = description_for(params)
    @og_image = StructuredData.image(@document, base_url) if @document
    @json_ld = json_ld_for(base_url)
  end

  def indexed? = !robots.to_s.include?("noindex")
  def og_type = @type == :record ? "article" : "website"
  def twitter_card = og_image ? "summary_large_image" : "summary"

  private

  def type_of(controller, action)
    case [ controller, action ]
    in [ "pages", "home" ] then :home
    in [ "pages", _ ] | [ "discover", _ ] then :page
    in [ "catalog", "index" ] then :results
    in [ "catalog", "show" ] then :record
    in [ "catalog", "advanced_search" ] then :advanced
    in [ "stock_catalog" | "branded_stock_catalog", "show" ] then :stock
    else :other
    end
  end

  def canonical_for(base_url, path, params)
    return nil if @type == :other

    CanonicalUrl.for(base_url, @type == :advanced ? "/catalog/advanced" : path, params)
  end

  def description_for(params)
    case @type
    when :home, :advanced then I18n.t("seo.description.#{@type}")
    when :page then I18n.t("seo.description.#{PAGE_DESCRIPTIONS.fetch(@path.delete_prefix('/').split('/').first, 'about')}")
    when :results then results_description(params)
    when :record, :stock then @document && !RobotsPolicy.withheld?(@document) ? StructuredData::Description.of(@document) : I18n.t("seo.description.record_withheld")
    end
  end

  def results_description(params)
    query = params.to_h.with_indifferent_access
    collection = Array(query.dig(:f, :collection_ssim)).first
    if query[:q].present? then I18n.t("seo.description.results_query", query: query[:q].to_s.squish.truncate(80))
    elsif collection then I18n.t("seo.description.results_collection", collection: collection)
    else I18n.t("seo.description.results")
    end
  end

  def json_ld_for(base_url)
    case @type
    when :home then [ StructuredData.site(base_url) ]
    when :record
      data = @document && StructuredData.record(@document, base_url: base_url, url: @canonical_url)
      data ? [ data ] : []
    else []
    end
  end
end
