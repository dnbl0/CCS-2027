# frozen_string_literal: true

# One run of Dam::Sync: "full", "incremental" or "reconcile". A full run's checkpoint is the end of the last date window it
# finished, so a run that stopped (status "running" or "failed") is resumed from there.
class DamSyncRun < ApplicationRecord
  KINDS = %w[full incremental reconcile].freeze

  validates :kind, inclusion: { in: KINDS }

  scope :finished, -> { where(status: "finished") }

  # When the newest finished run (of any kind) started: an incremental run reads what changed since then
  def self.last_started_at = finished.where(kind: %w[full incremental]).maximum(:started_at)

  # A full run that did not finish, to resume
  def self.unfinished_full = where(kind: "full", status: %w[running failed]).order(:started_at).last

  def finish! = update!(status: "finished", finished_at: Time.current)
  def fail!(error) = update!(status: "failed", finished_at: Time.current, error: "#{error.class}: #{error.message}".truncate(2000))
end
