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
  self.default_processor_chain += [ :add_minimum_should_match_to_solr, :limit_deep_paging, :add_highlighting_to_solr, :add_cjk_to_description,
                                    :add_synonyms_to_query, :ask_for_several_collations ]

  # Solr's cost grows with how deep a page starts, and nobody reads past page 250: a request deeper than this many records is answered
  # with the last page inside it (the ranking is unchanged). RESULTS_MAX_START overrides it.
  MAX_START = 10_000

  def add_minimum_should_match_to_solr(solr_parameters)
    return unless dismax?(solr_parameters)

    solr_parameters[:mm] = QuerySyntax.explicit?(search_state.params[:q]) ? BOOLEAN_MM : KEYWORD_MM
  end

  # Several spelling collations (solrconfig.xml asks for one), so an empty search's correction can be the one whose words sit
  # together in a record (SpellingCorrection.best_collation, CCS-292). Nothing for a request that turns the spelling check off.
  def ask_for_several_collations(solr_parameters)
    solr_parameters["spellcheck.maxCollations"] = SpellingCorrection::COLLATIONS unless solr_parameters[:spellcheck].to_s == "false"
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

  # CCS-56: the Description search also looks in the CJK description field, when the core has it (CjkIndex)
  def add_cjk_to_description(solr_parameters)
    return unless search_state.params[:search_field] == "description" && CjkIndex.available?

    solr_parameters[:qf] = "${description_qf}"
    solr_parameters[:pf] = "${description_pf}"
  end

  # config/synonyms.yml (QuerySynonyms): a plain keyword search also finds the versions of it with a word swapped for a synonym. The
  # visitor's edismax clause (q, or the one Blacklight puts in its JSON query) becomes "any of" the versions, each with the same
  # parser settings; the spelling check keeps reading the visitor's words (spellcheck.q). Only when the list has terms.
  def add_synonyms_to_query(solr_parameters)
    query = search_state.params[:q]
    return unless QuerySynonyms.any? && query.is_a?(String) && query.present?
    return if QuerySyntax.explicit?(query) || query.include?('"')

    versions = QuerySynonyms.versions(query)
    return if versions.size < 2

    any_of = ->(settings) { { bool: { should: versions.map { |version| { edismax: settings.merge(query: version) } } } } }
    if solr_parameters[:q] == query && dismax?(solr_parameters)
      solr_parameters.delete(:q)
      solr_parameters[:json] = (solr_parameters[:json] || {}).merge(query: { bool: { must: [ any_of.call({}) ] } })
    else
      # Blacklight's JSON query mixes string and symbol keys
      key = ->(hash, name) { hash.is_a?(Hash) ? (hash[name.to_s] || hash[name.to_sym]) : nil }
      musts = key.call(key.call(key.call(solr_parameters[:json], :query), :bool), :must)
      edismax = ->(clause) { key.call(clause, :edismax) }
      index = Array(musts).index { |clause| key.call(edismax.call(clause), :query) == query }
      return unless index

      musts[index] = any_of.call(edismax.call(musts[index]).to_h.transform_keys(&:to_sym).except(:query))
    end
    solr_parameters["spellcheck.q"] ||= query
  end

  private

  # Blacklight sends the advanced search form through the lucene parser (no mm)
  def dismax?(solr_parameters)
    solr_parameters[:defType].blank? || solr_parameters[:defType].to_s.include?("dismax")
  end
end
