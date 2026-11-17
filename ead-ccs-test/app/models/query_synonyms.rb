# frozen_string_literal: true

# Query-time synonyms from config/synonyms.yml, supplied by the collections team (empty until they are). The SearchBuilder sends a
# plain keyword search as the visitor's words OR each version with a word swapped for its synonym: "skull human" with the group
# [skull, cranium] finds what "skull human" finds and what "cranium human" finds. Each version is held to the same keyword match rule
# (SearchBuilder::KEYWORD_MM), so synonyms only ever add records. (Writing "(skull OR cranium) human" instead does not work: Solr's
# edismax applies that rule inside the brackets too, and would need both.) A search the visitor wrote with operators, quotes or a
# field (QuerySyntax) is theirs and is left alone. Nothing in Solr changes.
module QuerySynonyms
  FILE = Rails.root.join("config/synonyms.yml")
  MAX_VERSIONS = 8 # the visitor's own words included: a long query with many synonyms does not become a huge request

  module_function

  # The groups in a file: [[term, ...], ...], lower case, each with two or more terms
  def load_file(path)
    data = YAML.safe_load_file(path) || {}
    Array(data["groups"]).map { |group| Array(group).map { |term| clean(term).downcase }.compact_blank.uniq }.select { |group| group.size > 1 }
  rescue Errno::ENOENT, Psych::SyntaxError => error
    Rails.logger.warn("Synonyms not read from #{path}: #{error.message}")
    []
  end

  # Replaces the groups in use (nil goes back to the file's); for tests
  def use(groups)
    @groups = groups&.map { |group| group.map { |term| clean(term).downcase } }
    @pattern = nil
  end

  def groups = (@groups ||= load_file(FILE))

  def any? = groups.any?

  # The query and its versions with synonyms, the visitor's own first; just [query] when none of its words has synonyms
  def versions(query)
    query = query.to_s
    return [ query ] unless any? && pattern

    pieces = query.split(pattern, -1)
    matches = query.scan(pattern)
    return [ query ] if matches.empty?

    choices = matches.map { |match| [ match, *alternatives_for(match.downcase) ] }
    combinations = choices.first.product(*choices.drop(1))
    combinations.first(MAX_VERSIONS).map do |chosen|
      pieces.each_with_index.map { |piece, index| index < chosen.size ? piece + chosen[index] : piece }.join
    end.uniq
  end

  def alternatives_for(term) = groups.select { |group| group.include?(term) }.flatten.uniq - [ term ]

  # Only letters, digits, spaces, hyphens and apostrophes: a term from the file cannot carry query syntax
  def clean(term) = term.to_s.gsub(/[^[:alnum:]\s'-]/, " ").squish

  # Every term, longest first (so a phrase wins over a word inside it), as whole words
  def pattern
    @pattern ||= begin
      terms = groups.flatten.uniq.sort_by { |term| -term.length }
      Regexp.new("(?<![[:alnum:]'-])(?:#{terms.map { |term| Regexp.escape(term).gsub('\\ ', '\\s+') }.join('|')})(?![[:alnum:]'-])", Regexp::IGNORECASE) if terms.any?
    end
  end
end
