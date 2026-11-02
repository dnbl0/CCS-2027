# frozen_string_literal: true

# A visitor's request for access to a record (CCS-69). A record that is not licensed (AccessPolicy tier :request) is
# requested "to view"; a view-only record is requested "to download". The request is made without a login, so it holds
# the requester's name and email; staff action it from `bin/rails access_requests:export` until an admin screen exists.
class AccessRequest < ApplicationRecord
  REQUEST_TYPES = %w[view download].freeze
  STATUSES = %w[pending approved declined].freeze
  # The longest value accepted for each text field (the form shows them as maxlength too)
  LIMITS = { name: 200, email: 254, organisation: 200, purpose: 2000 }.freeze

  # The request type a record's tier calls for: nil for an open record, which needs no request.
  def self.request_type_for(tier) = { request: "view", view_only: "download" }[tier]

  validates :document_id, :document_title, :name, :email, :purpose, presence: true
  validates :request_type, inclusion: { in: REQUEST_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  LIMITS.each { |field, max| validates field, length: { maximum: max } }

  scope :pending, -> { where(status: "pending") }

  def view? = request_type == "view"
end
