# frozen_string_literal: true

# A named list of records a visitor keeps (CCS-389), owned by the guest user (no login). A visitor may have MAX_PER_USER
# lists; names are unique among their own, ignoring case. Its records are ListItems (Solr document ids).
class List < ApplicationRecord
  NAME_LIMIT = 80
  MAX_PER_USER = 25
  # A name made again within this many seconds is the same request twice (a double click), not a clash
  DOUBLE_SUBMIT_SECONDS = 10

  belongs_to :user
  has_many :list_items, dependent: :destroy

  validates :name, presence: true, length: { maximum: NAME_LIMIT }
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false }
  validate :user_has_room, on: :create

  before_validation { self.name = name.to_s.squish }

  # Alphabetical, as the lists page shows them
  scope :by_name, -> { order(Arel.sql("lower(lists.name)"), :id) }

  # The visitor's list of this name made a moment ago, if any: what a repeated "Create list" is answered with
  def self.just_made(user, name)
    return unless user.persisted?

    user.lists.where("lower(lists.name) = ?", name.to_s.squish.downcase).where(created_at: DOUBLE_SUBMIT_SECONDS.seconds.ago..).first
  end

  def full? = list_items.count >= ListItem::MAX_PER_LIST

  private

  def user_has_room
    errors.add(:base, :too_many_lists, count: MAX_PER_USER) if user && user.lists.count >= MAX_PER_USER
  end
end
