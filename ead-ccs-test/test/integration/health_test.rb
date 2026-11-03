require "test_helper"
require_relative "../support/outages"
require_relative "../support/env_override"

# /healthz (is the process alive) and /readyz (can it serve: database, Solr, migrations) for a load balancer or orchestrator (CCS-146).
# Solr is stood in for (Outages), so none of this needs it.
class HealthTest < ActionDispatch::IntegrationTest
  include Outages
  include EnvOverride

  # Solr answers its ping handler
  module SolrPing
    cattr_accessor :answer, default: nil

    def get(path, *args, **options)
      return super unless SolrPing.answer && path == "admin/ping"

      SolrPing.answer.call
    end
  end
  RSolr::Client.prepend(SolrPing) unless RSolr::Client < SolrPing

  setup { Readiness.reset! }
  teardown do
    SolrPing.answer = nil
    Readiness.reset!
  end

  def with_solr_ping(status = "OK")
    SolrPing.answer = -> { { "status" => status } }
    yield
  end

  test "/healthz says the process is alive, even with the database and Solr down" do
    with_database_down { with_solr_down { get "/healthz" } }

    assert_response :success
    assert_equal({ "status" => "ok" }, response.parsed_body)
  end

  test "/readyz is 200 with each check ok when the database, Solr and migrations are as needed" do
    with_solr_ping { get "/readyz" }

    assert_response :success
    assert_equal({ "status" => "ok", "checks" => { "database" => "ok", "solr" => "ok", "migrations" => "ok" } }, response.parsed_body)
  end

  test "/readyz is 503 when the database is down, and says which check failed" do
    with_solr_ping { with_database_down { get "/readyz" } }

    assert_response :service_unavailable
    assert_equal "unavailable", response.parsed_body["status"]
    assert_equal "fail", response.parsed_body.dig("checks", "database")
    assert_equal "ok", response.parsed_body.dig("checks", "solr")
  end

  test "/readyz is 503 when Solr is down" do
    with_solr_down { get "/readyz" }

    assert_response :service_unavailable
    assert_equal({ "database" => "ok", "solr" => "fail", "migrations" => "ok" }, response.parsed_body["checks"])
  end

  test "/readyz is 503 when Solr answers that it is not well" do
    with_solr_ping("ERROR") { get "/readyz" }

    assert_response :service_unavailable
  end

  test "READYZ_SOLR=optional keeps the instance in rotation while Solr is down: 200, degraded" do
    with_env("READYZ_SOLR" => "optional") { with_solr_down { get "/readyz" } }

    assert_response :success
    assert_equal "degraded", response.parsed_body["status"]
    assert_equal "fail", response.parsed_body.dig("checks", "solr")
  end

  test "/readyz is 503 when a migration is waiting" do
    with_solr_ping do
      pool = ActiveRecord::Base.connection_pool
      context = pool.migration_context
      context.define_singleton_method(:needs_migration?) { true }
      pool.define_singleton_method(:migration_context) { context }
      begin
        get "/readyz"
      ensure
        pool.singleton_class.remove_method(:migration_context)
        context.singleton_class.remove_method(:needs_migration?)
      end
    end

    assert_response :service_unavailable
    assert_equal "fail", response.parsed_body.dig("checks", "migrations")
  end

  test "a hung Solr cannot hold the probe: the check ends at the timeout" do
    SolrPing.answer = -> { sleep 5 }
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    with_env("READYZ_TIMEOUT_SECONDS" => "0.2") { get "/readyz" }

    assert_response :service_unavailable
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 2
  end

  test "Solr's answer is remembered briefly, so many probes make one ping" do
    pings = 0
    SolrPing.answer = -> { pings += 1; { "status" => "OK" } }
    3.times { get "/readyz" }

    assert_equal 1, pings
  end

  %w[/healthz /readyz].each do |path|
    test "#{path} is JSON, never cached, kept out of search results and sets no cookie" do
      with_solr_ping { get path }

      assert_equal "application/json", response.media_type
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
      assert_nil response.headers["Set-Cookie"]
    end

    test "#{path} is not counted by the rate limit" do
      with_env("RATE_LIMIT" => "on", "RATE_LIMIT_SEARCH_PER_MINUTE" => "1", "RATE_LIMIT_RECORD_PER_MINUTE" => "1") do
        with_solr_ping { 5.times { get path } }
      end

      assert_response :success
    end

    test "#{path} leaks nothing but the state of each check" do
      with_solr_ping { get path }
      json = response.parsed_body

      # Only these words, in this shape: no host, port, core, database name, version, count or message
      assert_equal %w[status], json.keys - [ "checks" ]
      assert_includes %w[ok unavailable degraded], json["status"]
      assert json["checks"].nil? || (json["checks"].keys.sort == %w[database migrations solr] && (json["checks"].values - %w[ok fail]).empty?)
    end
  end

  test "a failing check shows no error message, host, database name or version" do
    with_solr_down { with_database_down { get "/readyz" } }

    assert_no_match(/refused|connect|down \(test\)|ECONN|127\.0\.0\.1|8984|ead_ccs|ActiveRecord|Errno/i, response.body)
  end

  test "the Rails /up check still answers" do
    get "/up"

    assert_response :success
  end

  test "an unknown format or path under them is just a 404" do
    get "/healthz.json"
    assert_response :not_found
  end
end
