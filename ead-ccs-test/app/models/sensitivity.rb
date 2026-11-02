# frozen_string_literal: true

# Whether a record's digital assets are sensitive, so the visitor is asked before they are shown (CCS-227, CCS-21).
# This is the ONE place that decides it; nothing else reads the fields below, so the DAM's own flag can replace it.
#
# PLACEHOLDER RULE. The DAM's advisory is not in the index yet (the ingest keeps it in assets_json, as
# metadata.dAAdvisory1, with dAUseStatus beside it; real values not yet known). Until it is, the index carries two
# signal the collection staff wrote for the same purpose:
#   restrictions_tsi     "Not for publishing Sensitive|Culturally sensitive images. Only select images to be published online"
#                        (36 records: any restriction note that says "sensitive")
# (access_condition_ssi "Community Restricted", 1 record, is not here: AccessPolicy withholds it, as :request.)
# To switch to the DAM: change SENSITIVE_NOTE and .sensitive? (read dAAdvisory1);
# AccessPolicy, the record page and the bulk download only ask .sensitive?.
#
# What a visitor chose is kept in the session cookie only (Choices): "view" or "hide" per record, the latest MAX_CHOICES.
# It is not an access decision: AccessPolicy still decides what may be shown (a :request record stays withheld).
module Sensitivity
  SENSITIVE_NOTE = /\bsensitive\b/i

  # document: a SolrDocument (or anything answering #[])
  def self.sensitive?(document)
    Array(document["restrictions_tsi"]).any? { |note| note.to_s.match?(SENSITIVE_NOTE) }
  end

  # The visitor's choices for this session. Wraps the session hash; a value that is not "view" or "hide" is ignored.
  class Choices
    KEY = :sensitivity_choices
    VALUES = %w[view hide].freeze
    MAX_CHOICES = 40 # the cookie holds about 4 KB, shared with the rest of the session

    def initialize(session)
      @session = session
    end

    def viewing?(document_id) = choice(document_id) == "view"
    def declined?(document_id) = choice(document_id) == "hide"

    def record(document_id, value)
      return unless VALUES.include?(value.to_s)

      stored = current.except(document_id.to_s).merge(document_id.to_s => value.to_s)
      @session[KEY] = stored.to_a.last(MAX_CHOICES).to_h
    end

    private

    def choice(document_id) = current[document_id.to_s]

    def current
      stored = @session[KEY]
      stored.is_a?(Hash) ? stored.select { |id, value| id.is_a?(String) && VALUES.include?(value) } : {}
    end
  end
end
