# frozen_string_literal: true

# Blacklight's search service plus two additional behaviours:
# - when a search returns nothing offers a spelling collation, run the search again with the collation
#   and mark the response so the view can explain the substitution. (From CCS-123)
#   Solr does the heavy lifting. See spellcheck.maxCollationTries in solrconfig.xml
# - when a search with filters still returns nothing, count the results without its filters (ZeroResults), so the empty
#   page can offer them. Facet counts cannot give this: they are counted inside the filtered (empty) results.
# - when a search with filters finds none or few records, count what each filter on its own is hiding (ResultsDiagnostics), for
#   the "Why am I seeing these results?" panel (CCS-43). One more request per filter, only on those pages.
#
# Wired up as CatalogController.search_service_class, which is a class_attribute
# from Blacklight::Searchable rather than a blacklight_config property.
class SearchService < Blacklight::SearchService
  def search_results
    response = super
    correction = SpellingCorrection.from(search_state.query_param, response)
    response = retry_with(correction) || response if correction
    count_filter_removals(count_without_filters(response))
  end

  private

  # One rows=0 request with no facets, stats or spellcheck, made only for an empty page with filters. (merge, because
  # the builder's own rows= is overridden by the page size.)
  def count_without_filters(response)
    return response unless response.total.zero? && ZeroResults.filtered?(search_state.to_hash)

    state = search_state.reset(ZeroResults.without_filters(search_state.to_hash))
    builder = search_builder.with(state).merge(rows: 0, facet: false, stats: false, spellcheck: false)

    response.extend(ZeroResults::Response)
    response.unfiltered_total = repository.search(params: builder).total
    response
  end

  # One rows=0 request per filter (at most MAX_REMOVALS), each for the search without that filter. A search with a single filter
  # that found nothing has its answer already (unfiltered_total).
  def count_filter_removals(response)
    params = search_state.to_hash
    return response unless ResultsDiagnostics.applies?(total: response.total, params: params) && ZeroResults.filtered?(params)

    removals = ResultsDiagnostics.removals(params, blacklight_config.facet_fields).first(ResultsDiagnostics::MAX_REMOVALS)
    only_one_and_known = removals.one? && response.respond_to?(:unfiltered_total)
    response.extend(ResultsDiagnostics::Response)
    response.filter_removals = removals.map do |removal|
      removal.with_total(only_one_and_known ? response.unfiltered_total : count_for(removal.params))
    end
    response
  end

  def count_for(params)
    builder = search_builder.with(search_state.reset(params)).merge(rows: 0, facet: false, stats: false, spellcheck: false)
    repository.search(params: builder).total
  end

  # This mirrors Blacklight::SearchService#search_results rather than calling
  # it. Going back through search_state.reset keeps the retry on our own
  # SearchBuilder. Returns nil if the collation finds nothing after all, so the
  # caller can keep the original response.
  def retry_with(correction)
    state = search_state.reset(search_state.params.merge(q: correction.corrected))
    builder = search_builder.with(state)
    builder.page = state.page
    builder.rows = state.per_page

    corrected = repository.search(params: builder)
    return if corrected.documents.empty?

    corrected.extend(SpellingCorrection::Response)
    corrected.spelling_correction = correction
    corrected
  end
end
