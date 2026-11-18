# frozen_string_literal: true

# One production place and where it is (Geo::Geocoder fills it, Geo::SolrWriter reads it). docs/time-and-place.md
class PlaceGeocode < ApplicationRecord
  KINDS = %w[region country state place].freeze

  scope :looked_up, -> { where.not(looked_up_at: nil) }
  scope :found, -> { looked_up.where(not_found: false) }

  def located? = !not_found && lat.present? && lon.present?

  # The place's branch of the Place filter, broadest first: ["Oceania", "Australia", "Victoria", "Melbourne"]
  def hierarchy = Geo::Hierarchy.segments(self)
end
