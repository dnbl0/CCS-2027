# frozen_string_literal: true

# One record's thumbnail colours (rake colour:extract): its palette, colour names (buckets) and histogram, or why it could not be read
class RecordColour < ApplicationRecord
  scope :extracted, -> { where(error: nil) }
  scope :failed, -> { where.not(error: nil) }
end
