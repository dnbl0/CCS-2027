# frozen_string_literal: true

# Runs Dam::Sync on a schedule (config/recurring.yml): "incremental" every 10 minutes, "reconcile" weekly. One at a time: a run
# that is still going when the next is due makes the next wait (limits_concurrency). Does nothing, apart from a log line, where
# the DAM token or the sync's own Solr core is not configured (DAM_API_TOKEN, DAM_SOLR_URL), or before the first full run.
class DamSyncJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: "dam_sync", duration: 2.hours if respond_to?(:limits_concurrency)

  def perform(kind = "incremental")
    raise ArgumentError, "unknown DAM sync #{kind.inspect}" unless %w[incremental reconcile].include?(kind)
    return skip("DAM_API_TOKEN or DAM_SOLR_URL is not set") unless Dam::Client.configured? && ENV["DAM_SOLR_URL"].present?
    return skip("no full sync has finished yet (rake dam:sync FULL=1)") if kind == "incremental" && DamSyncRun.last_started_at.nil?

    Dam::Sync.new.public_send(kind)
  end

  private

  def skip(reason)
    Rails.logger.info("[dam] #{reason}; DamSyncJob skipped")
    nil
  end
end
