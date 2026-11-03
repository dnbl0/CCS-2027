# frozen_string_literal: true

# A named list of records a visitor keeps (CCS-389), owned by the guest user (no login). A visitor may have MAX_PER_USER
# lists; names are unique among their own, ignoring case. Its records are ListItems (Solr document ids).
class List < ApplicationRecord
  NAME_LIMIT = 80
  DESCRIPTION_LIMIT = 500
  # A share link's token: 24 random bytes, 32 URL-safe characters (192 bits), so a link cannot be guessed
  TOKEN_BYTES = 24
  TOKEN_FORMAT = /\A[A-Za-z0-9_-]{32}\z/
  MAX_PER_USER = 25

  belongs_to :user
  has_many :list_items, dependent: :destroy

  validates :name, presence: true, length: { maximum: NAME_LIMIT }
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false }
  validates :description, length: { maximum: DESCRIPTION_LIMIT }
  validate :user_has_room, on: :create
  validate :cover_is_in_list, if: :cover_document_id_changed?

  before_validation { self.name = name.to_s.squish }
  before_validation do
    self.description = description.to_s.squish.presence
    self.cover_document_id = cover_document_id.presence
  end

  # Alphabetical, as the lists page shows them
  scope :by_name, -> { order(Arel.sql("lower(lists.name)"), :id) }

  # The list of a share link; nil for a token that is malformed, unknown or revoked
  def self.find_shared(token)
    token = token.to_s
    token.match?(TOKEN_FORMAT) ? where.not(share_token: nil).find_by(share_token: token) : nil
  end

  def full? = list_items.count >= ListItem::MAX_PER_LIST

  def shared? = share_token.present?

  # Starts sharing, or changes the link when it is already shared (the old link then stops working)
  def share!(regenerate: false)
    return self if shared? && !regenerate

    update_columns(share_token: SecureRandom.urlsafe_base64(TOKEN_BYTES), shared_at: Time.current)
    self
  end

  # Stops sharing: the link is a 404 from now on
  def unshare! = update_columns(share_token: nil, shared_at: nil)

  # A copy for another visitor (a gallery's "Add to my list"): a new list of that visitor's, named like this one (made unique
  # among theirs), with the same description and records, in the order this list shows them. Not shared, no cover chosen
  # beyond the same record. Returns the new list; it is not saved when the visitor has no room for another list.
  def copy_for(user)
    copy = user.lists.build(name: name_free_for(user), description: description, cover_document_id: cover_document_id)
    return copy unless copy.save

    ids = list_items.recent.pluck(:document_id).reverse # oldest first, so the copy shows them in this list's order
    ids.each { |document_id| copy.list_items.create!(document_id: document_id) }
    copy
  end

  private

  def name_free_for(user)
    taken = user.lists.pluck(:name).to_set { |other| other.downcase }
    return name unless taken.include?(name.downcase)

    (2..MAX_PER_USER + 1).each do |number|
      suffix = " (#{number})"
      candidate = "#{name.first(NAME_LIMIT - suffix.size)}#{suffix}"
      return candidate unless taken.include?(candidate.downcase)
    end
    name
  end

  # The cover is one of the list's own records (a new list, a copy, takes its records afterwards)
  def cover_is_in_list
    return if cover_document_id.blank? || new_record?

    errors.add(:cover_document_id, :not_in_list) unless list_items.exists?(document_id: cover_document_id)
  end

  def user_has_room
    errors.add(:base, :too_many_lists, count: MAX_PER_USER) if user && user.lists.count >= MAX_PER_USER
  end
end
