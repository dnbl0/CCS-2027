# frozen_string_literal: true

module NexusCcs
  # A record's viewing classification as a small badge (CCS-44, CCS-496), on its result card and in its media toolbar: the
  # rating ("M") with its meaning for screen readers and on hover ("Classified M: mature, recommended for 15 and over"). Renders
  # nothing for a record without a rating. The rating is ViewingClassification's; the gate for a restricted one is
  # SensitivityGateComponent's.
  class ClassificationBadgeComponent < ViewComponent::Base
    def initialize(document:, size: :normal)
      @document = document
      @size = size
    end

    def render? = rating.present?

    def rating = ViewingClassification.rating(@document)
    def restricted? = ViewingClassification.restricted?(@document)
    def meaning = t("nexus_ccs.viewing_classification.meaning.#{rating.to_s.parameterize(separator: '_')}", default: rating.to_s)
    def label = t("nexus_ccs.viewing_classification.badge_label", rating: rating, meaning: meaning)

    def classes = [ "classification-badge", ("classification-badge--restricted" if restricted?), ("classification-badge--small" if @size == :small) ].compact.join(" ")

    def call
      content_tag(:span, class: classes, title: label) do
        safe_join([ content_tag(:span, rating, "aria-hidden": true),
                    content_tag(:span, label, class: "visually-hidden") ])
      end
    end
  end
end
