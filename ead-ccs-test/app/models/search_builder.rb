# frozen_string_literal: true

class SearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior
  include BlacklightRangeLimit::RangeLimitBuilder


  # How many of the user's terms a document has to match
  KEYWORD_MM = "4<-1 7<-2"
  BOOLEAN_MM = "0"

  # Appending puts this after Blacklight's own add_query_to_solr, so
  # solr_parameters[:q] is the query string Solr will receive.
  self.default_processor_chain += [ :add_minimum_should_match_to_solr, :limit_deep_paging ]

  # Solr's cost grows with how deep a page starts, and nobody reads past page 250: a request deeper than this many records is answered
  # with the last page inside it (the ranking is unchanged). RESULTS_MAX_START overrides it.
  MAX_START = 10_000

  def add_minimum_should_match_to_solr(solr_parameters)
    return unless dismax?(solr_parameters)

    solr_parameters[:mm] = QuerySyntax.explicit?(search_state.params[:q]) ? BOOLEAN_MM : KEYWORD_MM
  end

  def limit_deep_paging(solr_parameters)
    limit = Integer(ENV.fetch("RESULTS_MAX_START", MAX_START), exception: false) || MAX_START
    solr_parameters[:start] = limit if solr_parameters[:start].to_i > limit
  end

  private

  # Blacklight sends the advanced search form through the lucene parser (no mm)
  def dismax?(solr_parameters)
    solr_parameters[:defType].blank? || solr_parameters[:defType].to_s.include?("dismax")
  end
end
