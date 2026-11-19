# frozen_string_literal: true

module NexusCcs
  # The record page's line glyphs (24px grid, 2px stroke, drawn in the text colour), as the Figma Media / Control draws them: the
  # media's round tools and thumbnail steps (DigitalAssetsComponent) and the search stepper (ResultStepperComponent).
  module Glyphs
    PATHS = {
      plus: '<path d="M12 5v14M5 12h14"/>',
      minus: '<path d="M5 12h14"/>',
      maximize: '<path d="M3 8V3h5M16 3h5v5M21 16v5h-5M8 21H3v-5"/>',
      download: '<path d="M12 3v12M7 10l5 5 5-5M5 21h14"/>',
      info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>',
      close: '<path d="M6 6l12 12M18 6 6 18"/>',
      chevron_left: '<path d="m15 18-6-6 6-6"/>',
      chevron_right: '<path d="m9 18 6-6-6-6"/>',
      creative_commons: '<circle cx="12" cy="12" r="9"/><path d="M10.5 10.2a2.5 2.5 0 1 0 0 3.6M16.5 10.2a2.5 2.5 0 1 0 0 3.6"/>'
    }.freeze

    def self.svg(name, size: 20)
      body = PATHS.fetch(name)
      %(<svg width="#{size}" height="#{size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">#{body}</svg>).html_safe # rubocop:disable Rails/OutputSafety
    end
  end
end
