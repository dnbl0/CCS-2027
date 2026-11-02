# frozen_string_literal: true

# A search a visitor chose to keep from their search history (CCS-130). It holds a copy of the search's parameters
# (the same hash Blacklight's Search stores), so the link back to the results page is always built from what was saved.
class SavedSearch < ApplicationRecord
  NAME_LIMIT = 120

  belongs_to :user

  validates :name, presence: true, length: { maximum: NAME_LIMIT }
  validates :query_params, presence: true

  # Newest first, as the saved searches page lists them
  scope :recent, -> { order(created_at: :desc, id: :desc) }

  # The name given to a saved search when the visitor does not type one
  # TODO(human): turn the search's parameters (string keys, e.g. "q", "search_field", "f" => { "collection_ssim" => [...] })
  # into a short readable name for the saved searches page.
  def self.default_name(params)
    "Saved search"
  end

  # What the results page needs to repeat the search
  def search_params = query_params.to_h.symbolize_keys
end
