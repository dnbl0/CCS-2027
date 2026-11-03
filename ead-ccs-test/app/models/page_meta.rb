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
#   browse       Browse::Meta (hubs, entity pages) the page + its letter / page; JSON-LD CollectionPage (noindex when thin, filtered or on page 2 on)
#
# No image, and a general description, for a record the policy withholds or that is sensitive.
class PageMeta
  # The path's first segment => the key in seo.description; any other page is described as About
  PAGE_DESCRIPTIONS = { "accessibility" => "accessibility", "privacy" => "privacy", "help" => "help", "language-in-our-records" => "language", "discover" => "discover" }.freeze

  attr_reader :canonical_url, :robots, :description, :title, :og_image, :json_ld

  # controller/action: from the request; path/params: the request path and query parameters; document: on a record page
  # browse: a Browse::Meta, on the browse pages
  def initialize(controller:, action:, path:, params:, base_url:, title:, document: nil, browse: nil)
    @type = type_of(controller, action)
    @path = path.to_s
    @title = title.to_s
    @document = document if %i[record stock].include?(@type)
    @browse = browse if @type == :browse
    @canonical_url = canonical_for(base_url, path, params)
    @robots = RobotsPolicy.directive(path, params, document: @document, thin: thin_browse_page?(params))
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
    in [ "browse" | "browse_entities", _ ] then :browse
    else :other
    end
  end

  def canonical_for(base_url, path, params)
    return nil if @type == :other || (@type == :browse && @browse.nil?)
    return browse_canonical(base_url, path, params) if @type == :browse

    CanonicalUrl.for(base_url, @type == :advanced ? "/catalog/advanced" : path, params)
  end

  # The page itself, with the letter of a hub and the page of records when they make it a different page; the filter box is dropped
  def browse_canonical(base_url, path, params)
    params = params.to_h.stringify_keys
    kept = params.slice(*@browse.keep_params).compact_blank
    kept.delete("page") if kept["page"].to_i <= 1
    kept.empty? ? "#{base_url.to_s.chomp('/')}#{path}" : "#{base_url.to_s.chomp('/')}#{path}?#{kept.to_query}"
  end

  # A browse page too small to index, a filtered list, or the second page on
  def thin_browse_page?(params)
    return false unless @type == :browse && @browse

    params = params.to_h.stringify_keys
    @browse.thin? || params["filter"].present? || params["page"].to_i > 1
  end

  def description_for(params)
    return @browse&.description.to_s if @type == :browse

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
    when :browse then @browse ? @browse.json_ld(base_url, @canonical_url) : []
    when :record
      data = @document && StructuredData.record(@document, base_url: base_url, url: @canonical_url)
      data ? [ data ] : []
    else []
    end
  end
end
