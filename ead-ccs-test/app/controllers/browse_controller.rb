# frozen_string_literal: true

# Browse hubs and entity pages (docs/browse-and-entities.md): /browse, /browse/creators (places, subjects), /browse/time, and one page
# for each creator, place, subject and period. Public pages, built from Solr facets (Browse); nothing is stored. It is a CatalogController
# so that the records are drawn as the site's result cards, as a list's records are (ListsController).
class BrowseController < CatalogController
  layout "pages"

  copy_blacklight_config_from(CatalogController)
  blacklight_config.track_search_session.storage = false

  skip_before_action :apply_search_defaults, raise: false

  RELATED_LIMIT = 8
  OVERVIEW_FEATURED = 6

  helper_method :related_entities, :refine

  def index
    @indexes = Browse::Kind.all.to_h { |kind| [ kind, Browse::Index.for(kind) ] }
    @periods = Browse::Periods.counts
    use_meta Browse::Meta.overview, [ [ t("browse.title"), nil ] ]
  end

  def hub
    @kind = Browse::Kind.find(params[:kind]) || raise(ActionController::RoutingError, "Not Found")
    index = Browse::Index.for(@kind)
    @page = index.page(letter: params[:letter].to_s.upcase.presence, filter: params[:filter].to_s.first(80), page: params[:page])
    @index = index
    use_meta Browse::Meta.hub(@kind), [ [ t("browse.title"), browse_home_path ], [ @kind.plural, nil ] ]
  end

  def time
    @periods = Browse::Periods.counts
    use_meta Browse::Meta.time, [ [ t("browse.title"), browse_home_path ], [ t("browse.time.plural"), nil ] ]
  end

  def entity
    @kind = Browse::Kind.find(params[:kind]) || raise(ActionController::RoutingError, "Not Found")
    found = Browse::Index.for(@kind).find_by_slug(params[:slug]) || raise(ActionController::RoutingError, "Not Found")
    @entry, canonical = found
    return redirect_to(browse_entity_path(kind: @kind.key, slug: @entry.slug, **page_param), status: :moved_permanently) unless canonical

    @result = Browse::Profile.call(fq: @entry.fq, page: params[:page])
    wrap_response(@result)
    @search_query = @entry.search_query
    use_meta Browse::Meta.entity(@entry, @result), [ [ t("browse.title"), browse_home_path ], [ @kind.plural, browse_kind_path(@kind.key) ], [ @entry.name, nil ] ]
  end

  def period
    @period = Browse::Periods.parse(params[:slug]) || raise(ActionController::RoutingError, "Not Found")
    return redirect_to(browse_period_path(slug: @period.slug, **page_param), status: :moved_permanently) unless params[:slug] == @period.slug

    @result = Browse::Profile.call(fq: @period.fq, page: params[:page], periods: (@period.first..@period.last if @period.kind == :century))
    raise ActionController::RoutingError, "Not Found" if @result.total.zero?

    wrap_response(@result)

    @search_query = @period.search_query
    trail = [ [ t("browse.title"), browse_home_path ], [ t("browse.time.plural"), browse_time_path ] ]
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
