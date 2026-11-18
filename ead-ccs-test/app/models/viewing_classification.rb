# frozen_string_literal: true

# A record's viewing classification (CCS-44, CCS-496): the Australian film and game rating the collection gave its asset
# (digital_asset_advisory_classification_ssim, from the dev team's ingest: G, PG, M, MA 15+, R 18+, X 18+, RC, and one CTC).
#
#   rating   badge text                       restricted?
#   G        General                          no
#   PG       Parental guidance recommended    no
#   M        Mature, recommended 15+          no
#   MA 15+   Restricted to 15 and over        yes
#   R 18+    Restricted to 18 and over        yes
#   X 18+    Restricted to 18 and over        yes
#   RC       Refused classification           yes
#   CTC      Check the classification         yes (not rated yet, so treated with care)
#
# A restricted rating is asked about before its asset is shown, as sensitive material is: Sensitivity.sensitive? includes it,
# so the gate, the cards, share images and downloads all follow. Wording: config/locales/viewing_classification.en.yml
# (PLACEHOLDER: the University to approve).
module ViewingClassification
  FIELD = "digital_asset_advisory_classification_ssim"
  RATINGS = %w[G PG M MA\ 15+ R\ 18+ X\ 18+ RC CTC].freeze
  RESTRICTED = [ "MA 15+", "R 18+", "X 18+", "RC", "CTC" ].freeze

  # A Solr filter query that leaves out records with a restricted rating (for the picture pools of cards and features)
  EXCLUDE_RESTRICTED = "-#{FIELD}:(#{RESTRICTED.map { |rating| %("#{rating}") }.join(' ')})".freeze

  module_function

  # The record's ratings, as the index holds them
  def ratings(document) = Array(document[FIELD]).map { |value| value.to_s.strip }.compact_blank.uniq

  # The most restrictive rating, for the badge and the gate's wording (nil when the record has none)
  def rating(document) = ratings(document).max_by { |value| RATINGS.index(value) || -1 }

  def restricted?(document) = ratings(document).intersect?(RESTRICTED)
end
