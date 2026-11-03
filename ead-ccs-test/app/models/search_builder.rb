# frozen_string_literal: true

class SearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior
  include BlacklightRangeLimit::RangeLimitBuilder
  include AdvancedRules::SearchBuilderClauses # Advanced search rules with a fixed reading ("begins with", "is empty"...); old rows go to Blacklight's code


  # How many of the user's terms a document has to match
  KEYWORD_MM = "4<-1 7<-2"
  BOOLEAN_MM = "0"

  # Appending puts this after Blacklight's own add_query_to_solr, so
  # solr_parameters[:q] is the query string Solr will receive.
  self.default_processor_chain += [ :add_minimum_should_match_to_solr, :add_highlighting_to_solr ]

  def add_minimum_should_match_to_solr(solr_parameters)
    return unless dismax?(solr_parameters)

    solr_parameters[:mm] = QuerySyntax.explicit?(search_state.params[:q]) ? BOOLEAN_MM : KEYWORD_MM
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
