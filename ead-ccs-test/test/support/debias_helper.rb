# frozen_string_literal: true

# Test doubles for the de-bias term list. Tests use harmless made-up words only; the real list is the collections team's.
module DebiasHelper
  def debias_entry(term, **attributes)
    { term: term, explanation: "Made-up explanation for #{term}.", source: "Test", reviewed_on: "2026-11-03", enabled: true }.merge(attributes)
  end

  def with_debias_terms(*entries, &block)
    DebiasTerms.use(entries.map { |entry| entry.is_a?(String) ? debias_entry(entry) : entry }, &block)
  end
end
