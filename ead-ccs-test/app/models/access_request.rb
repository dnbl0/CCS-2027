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

  # The same request arriving again within this many seconds is a double click or a retry, not a second request
  DOUBLE_SUBMIT_SECONDS = 600

  # Saves the request once, however many times it arrives (CCS-147): two requests at once are made to take turns by a lock on the
  # record, email and kind, and the second is answered with the first. Returns the request (check persisted?; errors if invalid).
  def self.submit(attributes)
    request = new(attributes)
    return request unless request.valid?

    transaction do
      lock_key = [ "access_request", request.document_id, request.email.downcase, request.request_type ].join(":")
      connection.execute(sanitize_sql_array([ "SELECT pg_advisory_xact_lock(hashtext(?))", lock_key ]))
      earlier = where(document_id: request.document_id, request_type: request.request_type, name: request.name, purpose: request.purpose)
                .where("lower(email) = ?", request.email.downcase).where(created_at: DOUBLE_SUBMIT_SECONDS.seconds.ago..).first
      earlier || request.tap(&:save)
    end
  end

  scope :pending, -> { where(status: "pending") }

  def view? = request_type == "view"
end
