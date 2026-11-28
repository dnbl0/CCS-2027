# frozen_string_literal: true

# A substitution SearchService made when a search returned nothing and Solr
# offered a spelling collation that does have results. Carries what was typed,
# searched for instead, and the lesser suggestions the offered as links.
SpellingCorrection = Struct.new(:original, :corrected, :suggestions) do
  # Returns nil when there is nothing to correct, the search found something,
  # or Solr had no collation.
  # near_hits, when given, counts the records holding a collation's words near each other (see best_collation).
  def self.from(query, response, near_hits = nil)
    return if query.blank?

    return unless response.respond_to?(:documents) && response.documents.empty?

    collation = (best_collation(response, near_hits) if near_hits && response.is_a?(Hash)) || response.spelling&.collation
    collation = collation.to_s
    return if collation.blank? || collation.casecmp?(query)

    new(query, collation, other_suggestions(response, collation))
  end

  # Solr ranks its collations by how common each corrected word is, word by word, so "gardin of coty" became "garden of
  # copy": "copy" is commoner than "city", though no record has "garden" near "copy" (CCS-292). The first collation of
  # several words whose words sit together in the most records wins (Solr's order breaks a tie); Solr's own first when none
  # has them together, or when it is one word.
  def self.best_collation(response, near_hits)
    collations = Array(response.dig("spellcheck", "collations")).each_slice(2)
                                                                .filter_map { |key, value| value if key == "collation" }
                                                                .map { |value| value.is_a?(Hash) ? value["collationQuery"] : value.to_s }
    return collations.first if collations.first.to_s.split.size < 2

    hits = collations.map { |collation| near_hits.call(collation) }
    best = hits.max
    best.to_i.positive? ? collations[hits.index(best)] : collations.first
  end

  # Solr's remaining 'lesser' suggestions, so the as clickable alternatives the way
  # Blacklight's "did you mean" list behaves.
  def self.other_suggestions(response, collation)
    words = Array(response.spelling.try(:words))
    words.reject { |word| word.casecmp?(collation) }
  end
end

# Reopening rather than nesting inside the Struct.new block above to give the `module`
# keyword the correct scope.
class SpellingCorrection
  # How many collations a search asks Solr for (SearchBuilder#ask_for_several_collations)
  COLLATIONS = 5

  # Mixed into a retried Solr response so views can reach the correction.
  module Response
    attr_accessor :spelling_correction
  end
end
