# frozen_string_literal: true

module NexusCcs
  # Why a result matched (CCS-39), under the card's lines: "Matched in: Title, Creator", and, when the words are in a field the
  # card does not show (most often the description), a short snippet with them marked. Highlighting (<mark>) is the extra
  # cue, never the only one: the sentence names the fields, and the marked words are readable text either way.
  # Nothing is drawn for a record with no highlighting (no search words, or the page did not ask Solr).
  class MatchRationaleComponent < ViewComponent::Base
    # match: SearchHighlighting::Match; show_snippet: false for a record whose description is withheld (RobotsPolicy.withheld?)
    # pdf: the search was Full text (PDF), so every result was found in the text of its PDF (CCS-36)
    def initialize(match:, show_snippet: true, pdf: false)
      @match = match
      @show_snippet = show_snippet
      @pdf = pdf
    end

    attr_reader :match

    def render? = @pdf || match.present?

    def summary
      return t("nexus_ccs.rationale.pdf") if @pdf

      match.any? ? t("nexus_ccs.rationale.matched_in", fields: match.labels.join(", ")) : t("nexus_ccs.rationale.other")
    end

    def snippet = @show_snippet && !@pdf ? match.snippet : nil
  end
end
