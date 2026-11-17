require "test_helper"
require_relative "../support/env_override"

class DamSyncJobTest < ActiveJob::TestCase
  include EnvOverride

  test "without the DAM token or the sync's own core it does nothing" do
    with_env("DAM_API_TOKEN" => nil, "DAM_SOLR_URL" => "http://127.0.0.1:1/solr/x") do
      assert_nil DamSyncJob.perform_now("incremental")
    end
    with_env("DAM_API_TOKEN" => "x", "DAM_SOLR_URL" => nil) do
      assert_nil DamSyncJob.perform_now("reconcile")
    end
    assert_equal 0, DamSyncRun.count
  end

  test "an incremental run waits for the first full sync" do
    with_env("DAM_API_TOKEN" => "x", "DAM_SOLR_URL" => "http://127.0.0.1:1/solr/x") do
      assert_nil DamSyncJob.perform_now("incremental")
    end
    assert_equal 0, DamSyncRun.count
  end

  test "only incremental and reconcile runs are scheduled" do
    assert_raises(ArgumentError) { DamSyncJob.perform_now("full") }
  end

  test "the schedule runs the incremental sync every 10 minutes and the reconcile weekly" do
    tasks = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).fetch("production")
    assert_equal [ "incremental" ], tasks.dig("dam_sync", "args")
    assert_equal "every 10 minutes", tasks.dig("dam_sync", "schedule")
    assert_equal [ "reconcile" ], tasks.dig("dam_reconcile", "args")
    assert_match(/every sunday/, tasks.dig("dam_reconcile", "schedule"))
  end
end
