# frozen_string_literal: true

class SearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior
  include BlacklightRangeLimit::RangeLimitBuilder


  # How many of the user's terms a document has to match
  KEYWORD_MM = "4<-1 7<-2"
  BOOLEAN_MM = "0"

  # Appending puts this after Blacklight's own add_query_to_solr, so
  # solr_parameters[:q] is the query string Solr will receive.
  self.default_processor_chain += [ :add_minimum_should_match_to_solr, :limit_deep_paging, :add_highlighting_to_solr ]

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

  # Display only (CCS-39): asks Solr which fields held the visitor's words, for the results page's "Matched in" line. The hl*
  # parameters add a "highlighting" section to the response and leave the matching and the order alone. Nothing for a
  # request that returns no records (counts, facets).
  def add_highlighting_to_solr(solr_parameters)
    return if solr_parameters[:rows].to_i.zero?

    solr_parameters.merge!(SearchHighlighting.parameters(search_state))
  end

  private

  # Blacklight sends the advanced search form through the lucene parser (no mm)
  def dismax?(solr_parameters)
    solr_parameters[:defType].blank? || solr_parameters[:defType].to_s.include?("dismax")
  end
end
