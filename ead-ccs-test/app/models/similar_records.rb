# frozen_string_literal: true

# The records most like one record, for the "Similar records" section of the record page (docs/similar-and-trending.md).
#
# Solr's More Like This query parser ({!mlt}) reads the record's own values in the fields below, keeps the most telling terms
# (those that are frequent enough in the record, rare enough in the index) and finds the records that share them. It is a
# built-in parser of the /select handler, so no Solr configuration or reindex is needed. The parser is given the record's id
# through a request parameter (v=$src), never in the query text, so an id cannot change the query.
#
# On top of that score, two small nudges, as optional clauses of the same query:
#   - a record with a digital asset ranks above an equal one without (the section is a picture gallery first)
#   - a record made within 25 years of this one ranks above an equal one made long before or after (MLT cannot read numbers)
# The record itself is excluded. Records the discovery sections never show (Discovery.listable?) are dropped, and so are the
# weak matches: a result scoring under MIN_SCORE_RATIO of the best one is not "similar" (a long tail of one shared word).
#
# Idea from Europeana (record recommendations built from a record's own metadata); written from the Solr documentation,
# with no Europeana code.
class SimilarRecords
  # Field => weight. Whole-value fields (_ssim) match only the identical value ("Lees, Derwent"), so the creator is the
  # strongest signal; title words are weaker (titles repeat words such as "Untitled"); the collection is only a tiebreak.
  QUERY_FIELDS = {
    "creator_ssim" => 3.0, "subject_ssim" => 2.5, "associated_subject_ssim" => 1.0, "object_type_ssim" => 2.0,
    "classification_ssim" => 1.5, "title_tsim" => 1.5, "production_place_ssim" => 1.0, "cultural_group_ssim" => 1.5,
    "collection_ssim" => 0.3
  }.freeze
  MIN_TERM_FREQUENCY = 1    # mintf: a term need occur once in the record
  MIN_DOC_FREQUENCY = 2     # mindf: a term only this record has cannot find anything similar
  MAX_DOC_FREQUENCY = 8_000 # maxdf: a term in this many records (a fifth of the index) tells nothing
  MAX_QUERY_TERMS = 25      # maxqt
  IMAGE_BOOST = 6.0
  DATE_BOOST = 4.0
  DATE_WINDOW = 25          # years either side
  CANDIDATES = 30           # asked for, so that dropping unlistable and weak ones still leaves enough
  SHOWN = 6                 # cards in the section
  MINIMUM = 2               # fewer than this and the section is not shown
  MIN_SCORE_RATIO = 0.35
  MAX_PER_CREATOR = 3       # so a prolific creator's series does not fill the section

  # document: the record. Returns up to `shown` SolrDocuments, or [] when there are fewer than MINIMUM, the record may not be
  # listed (withheld or sensitive: no recommendations beside it), or Solr cannot answer.
  def self.for(document, shown: SHOWN)
    return [] unless document && Discovery.listable?(document)

    found = new(document).documents.first(shown)
    found.size >= MINIMUM ? found : []
  rescue StandardError => error
    Discovery.log_failure("Similar records", error)
    []
  end

  def initialize(document)
    @document = document
  end

  def documents
    candidates = Discovery.search(params).documents.reject { |candidate| candidate.id == @document.id }
    best = candidates.filter_map { |candidate| candidate["score"] }.max.to_f
    kept = candidates.select { |candidate| Discovery.listable?(candidate) && strong?(candidate, best) }
    varied(kept)
  end

  # The request (the parameters are named sim_*: a parameter called mlt would switch on Solr's MoreLikeThis component): q is a Boolean query (the MLT clause must match; the image and date clauses only add score)
  def params
    request = {
      q: "{!bool must=$sim_mlt should=$sim_image#{' should=$sim_near' if year}}", fq: "-{!term f=id v=$src}", rows: CANDIDATES,
      fl: "#{Discovery::FIELDS.join(',')},score", src: @document.id.to_s, sim_mlt: mlt_clause, sim_image: "has_digital_asset_bsi:true^#{IMAGE_BOOST}"
    }
    request[:sim_near] = "date_start_isi:[#{year - DATE_WINDOW} TO #{year + DATE_WINDOW}]^#{DATE_BOOST}" if year
    request
  end

  private

  def mlt_clause
    qf = QUERY_FIELDS.map { |field, weight| "#{field}^#{weight}" }.join(" ")
    "{!mlt qf=\"#{qf}\" mintf=#{MIN_TERM_FREQUENCY} mindf=#{MIN_DOC_FREQUENCY} maxdf=#{MAX_DOC_FREQUENCY} maxqt=#{MAX_QUERY_TERMS} boost=true v=$src}"
  end

  def year
    value = @document["date_start_isi"].to_i
    value if value.positive?
  end

  # In score order, at most MAX_PER_CREATOR records of any one creator
  def varied(candidates)
    seen = Hash.new(0)
    candidates.select do |candidate|
      creator = Array(candidate["creator_ssim"]).first
      creator.blank? || (seen[creator] += 1) <= MAX_PER_CREATOR
    end
  end

  def strong?(candidate, best)
    best.zero? || candidate["score"].to_f >= best * MIN_SCORE_RATIO
  end
end
