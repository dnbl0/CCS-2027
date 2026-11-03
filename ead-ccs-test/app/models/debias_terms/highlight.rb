# frozen_string_literal: true

module DebiasTerms
  # A field value with its flagged terms marked, for the record page. The text itself is not changed: every character of the value
  # is still there, escaped; each find is wrapped in <mark> with a visually hidden "flagged term:" before it, so a screen reader
  # (and anyone who cannot see the mark's style) is told, and the mark's underline is not the only signal. The result is html_safe
  # because everything in it is escaped here or fixed markup.
  module Highlight
    module_function

    # matches: the Matches for THIS value (same field and value_index); label: the hidden words, from the locale
    def call(value, matches, label:)
      text = DebiasTerms.normalise(value)
      return ERB::Util.html_escape(text) if matches.empty?

      html = +""
      cursor = 0
      ranges(matches).each do |start, finish|
        html << ERB::Util.html_escape(text[cursor...start])
        html << %(<mark class="debias-flag"><span class="visually-hidden">#{ERB::Util.html_escape(label)} </span>) <<
          ERB::Util.html_escape(text[start...finish]) << "</mark>"
        cursor = finish
      end
      html << ERB::Util.html_escape(text[cursor..])
      html.html_safe # rubocop:disable Rails/OutputSafety -- every piece is escaped above
    end

    # The matches' [start, finish] ranges, in order, with overlapping ones joined, so no mark is inside another
    def ranges(matches)
      matches.map { |match| [ match.start, match.finish ] }.sort.each_with_object([]) do |(start, finish), merged|
        if merged.any? && start < merged.last[1] then merged.last[1] = [ merged.last[1], finish ].max
        else merged << [ start, finish ]
        end
      end
    end
  end
end
