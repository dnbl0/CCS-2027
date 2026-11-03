# frozen_string_literal: true

# The page of one maker, place, subject or period (docs/browse-and-entities.md), reached from the browse index pages (BrowseController) and
# the record page. Public, built from Solr facets (Browse); nothing is stored. It is a CatalogController so that the records are drawn
# as the site's result cards, as a list's records are (ListsController).
class BrowseEntitiesController < CatalogController
  layout "pages"

  copy_blacklight_config_from(CatalogController)
  blacklight_config.track_search_session.storage = false

  skip_before_action :apply_search_defaults, raise: false

  # The value list cannot be had (Solr down and no copy kept): say so plainly, as the browse pages do
  rescue_from Browse::Index::Unavailable, with: :browse_unavailable

  RELATED_LIMIT = 8

  helper_method :related_entities, :refine

  def entity
    @kind = Browse::Kind.find(params[:kind]) || raise(ActionController::RoutingError, "Not Found")
    found = Browse::Index.for(@kind).find_by_slug(params[:slug]) || raise(ActionController::RoutingError, "Not Found")
    @entry, canonical = found
    return redirect_to(browse_entity_path(kind: @kind.key, slug: @entry.slug, **page_param), status: :moved_permanently) unless canonical

    @result = Browse::Profile.call(fq: @entry.fq, page: params[:page])
    wrap_response(@result)
    @search_query = @entry.search_query
    use_meta Browse::Meta.entity(@entry, @result), [ [ t("browse.title"), browse_path ], [ @kind.plural, browse_hub_path(@kind.key) ], [ @entry.name, nil ] ]
  end

  def period
    @period = Browse::Periods.parse(params[:slug]) || raise(ActionController::RoutingError, "Not Found")
    return redirect_to(browse_period_path(slug: @period.slug, **page_param), status: :moved_permanently) unless params[:slug] == @period.slug

    @result = Browse::Profile.call(fq: @period.fq, page: params[:page], periods: (@period.first..@period.last if @period.kind == :century))
    raise ActionController::RoutingError, "Not Found" if @result.total.zero?

    wrap_response(@result)

    @search_query = @period.search_query
    trail = [ [ t("browse.title"), browse_path ], [ t("browse.periods"), browse_hub_path("periods") ] ]
    trail << [ @period.parent.label, browse_period_path(slug: @period.parent.slug) ] if @period.parent
    use_meta Browse::Meta.period(@period, @result.total), trail + [ [ @period.label, nil ] ]
  end

  # Blacklight uses #search_action_url for the header's search box
  def search_action_url(*)
    search_catalog_url(*)
  end

  private

  # Blacklight's helpers (the Save control's bookmarks) read the page's documents from @response, as in ListsController
  def wrap_response(result)
    docs = result.documents.map(&:_source)
    @response = Blacklight::Solr::Response.new({ "response" => { "docs" => docs, "numFound" => docs.size, "start" => 0 } }, {},
                                               blacklight_config: blacklight_config)
  end

  def browse_unavailable
    render "browse_entities/unavailable", status: :service_unavailable
  end

  def use_meta(meta, trail)
    @browse_meta = meta
    @browse_trail = trail
  end

  def page_param = params[:page].to_i > 1 ? { page: params[:page].to_i } : {}

  # The records' facet values of one field as [[Entry, count], ...] with an entity page of their own, most records first. `except` is
  # the entity the page is about.
  def related_entities(kind, facets, except: nil)
    index = (@related_indexes ||= {})[kind.key] ||= Browse::Index.for(kind)
    pairs = facets.filter_map do |value, count|
      entry = index.find_value(value)
      [ entry, count ] if entry && entry != except
    end
    pairs.uniq(&:first).first(RELATED_LIMIT)
  end

  # The same records, narrowed to one more value of a field (the page's main collections, object types)
  def refine(query, field, value) = query.deep_merge(f: { field => [ value ] })
end
