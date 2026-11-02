# frozen_string_literal: true

# One record (a Solr document id) in a List (CCS-389). A list holds at most MAX_PER_LIST records, each once.
class ListItem < ApplicationRecord
  MAX_PER_LIST = 200

  belongs_to :list

  validates :document_id, presence: true, uniqueness: { scope: :list_id }
  validate :list_has_room, on: :create

  # Newest first, as a list shows its records
  scope :recent, -> { order(created_at: :desc, id: :desc) }

  private

  def list_has_room
    errors.add(:base, :list_full, count: MAX_PER_LIST) if list&.full?
  end
end
