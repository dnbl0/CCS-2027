# frozen_string_literal: true

# The one way to put a value into Solr query text. Prefer passing a value as a parameter of a {!term} query (similar_rows.rb,
# collection_stories/solr_matcher.rb); where a query must hold the value itself (facet.query keys, OR-ed and boosted clauses,
# range bounds), quote it here: a phrase in double quotes with its quotes and backslashes escaped, so no value can change the
# query's meaning.
module SolrQuery
  module_function

  # "value" with " and \ escaped
  def phrase(value) = %("#{value.to_s.gsub(/["\\]/) { |char| "\\#{char}" }}")

  # field:("a" OR "b"): records with any of the values
  def field(field, values) = "#{field}:(#{Array(values).map { |value| phrase(value) }.join(' OR ')})"
end
