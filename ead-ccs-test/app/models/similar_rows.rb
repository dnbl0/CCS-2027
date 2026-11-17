# frozen_string_literal: true

# The labelled rows under a record, after "Similar objects" (docs/similar-and-trending.md): More by this creator, From the same
# period, From the same place, More of this type. Each row is one Solr request for records that share a value of the record's
# own (any of them), loaded in its own lazy Turbo frame (SimilarController, ?row=), so the record page itself still makes one
# request. The same rules as Similar objects: only records Discovery lists, with an image this visitor may see
# (SimilarRecords::ASSET_FILTERS and SimilarRecords.shows_image?), never the record itself; a withheld or sensitive record has
# no rows at all. A row with nothing in it is not drawn.
#
# Fields a core may not have yet (date_era_ssim, region_ssim) are read when they are there: a record without them falls back to
# its start year (period) or its place of production (place), and a row with nothing to match on is not offered.
class SimilarRows
  # The row => the fields it matches on, in order of preference: the first the record has a value in is used (region before place of
  # production, object type before classification); the period row falls back to the start year
  FIELDS = {
    "creator" => %w[creator_ssim],
    "period" => %w[date_era_ssim],
    "place" => %w[region_ssim production_place_ssim],
    "type" => %w[object_type_ssim classification_ssim]
  }.freeze
  KEYS = FIELDS.keys.freeze
  YEAR_FIELD = "date_start_isi"
  DATE_WINDOW = SimilarRecords::DATE_WINDOW # years either side, as Similar objects' nudge
  # What the source record must be fetched with, beyond Discovery::FIELDS
  SOURCE_FIELDS = (Discovery::FIELDS + FIELDS.values.flatten + [ YEAR_FIELD ]).uniq.freeze
  SHOWN = 8
  CANDIDATES = 24           # asked for, so that dropping unlistable ones still leaves enough
  MAX_VALUES = 3            # a record with many values does not make a vague row
  MAX_PER_CREATOR = SimilarRecords::MAX_PER_CREATOR # in the rows that are not about the creator
  # Values that say nothing about the record (an unknown maker, a placeholder place)
  NOISE = %r{\A\s*(unknown|anonymous|unidentified|not (recorded|known|stated)|n/?a|none|various)\b}i

  # The rows a record can have, in order: none for a record that may not have recommendations beside it
  def self.keys_for(document)
    return [] unless document && Discovery.listable?(document)

    KEYS.select { |key| new(document, key).matchable? }
  end

  # Up to SHOWN SolrDocuments for the row, or [] (nothing to match on, a record that may not be listed, Solr failing)
  def self.for(document, key, exclude: [])
    return [] unless KEYS.include?(key.to_s) && keys_for(document).include?(key.to_s)

    new(document, key, exclude: exclude).documents
  rescue StandardError => error
    Discovery.log_failure("Similar rows", error)
    []
  end

  attr_reader :key

  def initialize(document, key, exclude: [])
    @document = document
    @key = key.to_s
    @skip = Array(exclude).map(&:to_s).push(document.id.to_s)
  end

  # field => [values] the row matches on: one field, the first the record has values in
  def values
    @values ||= FIELDS.fetch(key).lazy.map { |field| [ field, clean(@document[field]) ] }.find { |_field, list| list.any? }.then { |pair| pair ? [ pair ].to_h : {} }
  end

  # The start year, for a period row with no era: records made within DATE_WINDOW years of it
  def year
    value = Array(@document[YEAR_FIELD]).first
    value.to_i if key == "period" && values.empty? && value.to_s.match?(/\A-?\d+\z/)
  end

  def matchable? = values.any? || !year.nil?

  # The search behind "See all": only when the row matches one value of one field (it is then exactly that filter)
  def see_all_query
    field, list = values.first
    { "f" => { field => list } } if values.one? && list.one?
  end

  # The values the row is about, for its description ("Lees, Derwent"; "Oceania, Melbourne")
  def described = values.values.flatten.uniq

  def documents
    found = Discovery.search(params).documents.reject { |candidate| @skip.include?(candidate.id.to_s) }
    kept = found.select { |candidate| Discovery.listable?(candidate) && SimilarRecords.shows_image?(candidate) }
    varied(kept).first(SHOWN)
  end

  # One request: q is a Boolean "any of" of term queries, each value passed as a parameter (never in the query text); the year range
  # is built from an integer. similar_row names the row (it also lets a test tell the request apart).
  def params
    clauses = {}
    values.each do |field, list|
      list.each do |value|
        index = clauses.size
        clauses[:"sim_r#{index}"] = "{!term f=#{field} v=$sim_v#{index}}"
        clauses[:"sim_v#{index}"] = value
      end
    end
    clauses[:"sim_r#{clauses.size / 2}"] = "#{YEAR_FIELD}:[#{year - DATE_WINDOW} TO #{year + DATE_WINDOW}]" if year
    shoulds = clauses.keys.grep(/\Asim_r/).map { |name| "should=$#{name}" }.join(" ")
    { q: "{!bool #{shoulds}}", fq: [ "-{!term f=id v=$src}", *SimilarRecords::ASSET_FILTERS ], rows: CANDIDATES, src: @document.id.to_s,
      similar_row: key, fl: Discovery::FIELDS.join(","), **clauses }
  end

  private

  def clean(list)
    Array(list).map { |value| value.to_s.strip }.reject { |value| value.empty? || value.match?(NOISE) }.uniq.first(MAX_VALUES)
  end

  def varied(candidates)
    return candidates if key == "creator"

    seen = Hash.new(0)
    candidates.select do |candidate|
      creator = Array(candidate["creator_ssim"]).first
      creator.blank? || (seen[creator] += 1) <= MAX_PER_CREATOR
    end
  end
end
