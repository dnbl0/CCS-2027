# frozen_string_literal: true

module NexusCcs
  # The slim sub-navigation under the site header on a wide record page (from 1200px; it is not drawn below that): the record's title
  # on the left, anchors to the page's sections on the right, after Apple's product pages. It sticks to the top of the window, so
  # the page sets a scroll padding (record_page.css) and a focused control is never hidden under it (WCAG 2.4.11). The anchors that
  # lead nowhere are left out (More like this is drawn only for a record that may have recommendations).
  class RecordSubnavComponent < ViewComponent::Base
    def initialize(document:, details: true)
      @document = document
      @details = details
    end

    def title = Array(@document["title_tsim"]).first.presence || @document.id.to_s

    def links
      @links ||= [
        [ t("nexus_ccs.record_page.subnav.overview"), "#record-overview" ],
        (details? ? [ t("nexus_ccs.record_page.sections.object_details"), "#record-details" ] : nil),
        [ t("nexus_ccs.record_page.sections.copyright"), "#record-copyright" ],
        [ t("nexus_ccs.record_page.sections.about"), "#about-this-record" ],
        (Discovery.listable?(@document) ? [ t("nexus_ccs.record_page.more_like_this.heading"), "#more-like-this" ] : nil)
      ].compact
    end

    def details? = @details
  end
end
