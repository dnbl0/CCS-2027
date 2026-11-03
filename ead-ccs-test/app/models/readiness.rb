# frozen_string_literal: true

require "timeout"

# Whether this instance can serve visitors (/readyz, HealthController; CCS-146). Three checks, each quick and each bounded:
#   database    a SELECT 1 on a pooled connection
#   solr        Solr's ping handler, on its own short timeouts (the circuit breaker is not consulted, so recovery is seen at once)
#   migrations  none waiting to run
# Solr's answer is remembered for READYZ_CACHE_SECONDS (default 2) so that many probes cost Solr one ping. Returns "ok" or
# "fail" for each check and never an error message, a host name, a version or a count. READYZ_SOLR=optional keeps a Solr outage
# from failing readiness (the status is then "degraded", HTTP 200): use it when the site should stay in rotation, serving its
# pages that do not search, while Solr is down. READYZ_TIMEOUT_SECONDS (default 2) bounds each check.
module Readiness
  Result = Data.define(:status, :checks) do
    def ready? = status != "unavailable"

    def to_h = { status: status, checks: checks }
  end

  @mutex = Mutex.new
  @solr = nil

  class << self
    def call
      checks = { "database" => run { database }, "solr" => solr_cached, "migrations" => run { migrations } }
      Result.new(status(checks), checks)
    end

    # Forgets the remembered Solr answer (tests)
    def reset! = @mutex.synchronize { @solr = nil }

    private

    def status(checks)
      required = checks.except(*("solr" if solr_optional?))
      return "unavailable" if required.values.include?("fail")

      checks.values.include?("fail") ? "degraded" : "ok"
    end

    def solr_optional? = ENV["READYZ_SOLR"] == "optional"

    def database
      ActiveRecord::Base.connection_pool.with_connection { |connection| connection.select_value("SELECT 1") == 1 }
    end

    # A database that cannot be reached cannot say; that is "fail" for migrations too
    def migrations = !ActiveRecord::Base.connection_pool.migration_context.needs_migration?

    def solr_cached
      ttl = Float(ENV.fetch("READYZ_CACHE_SECONDS", 2), exception: false) || 2
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @mutex.synchronize do
        return @solr[:value] if @solr && now - @solr[:at] < ttl

        @solr = { value: run { solr }, at: now }
        @solr[:value]
      end
    end

    # Solr's ping handler, on a client of its own with short timeouts
    def solr
      timeout = seconds
      client = RSolr.connect(url: Blacklight.default_index.blacklight_config.connection_config.fetch(:url), open_timeout: timeout, timeout: timeout)
      client.get("admin/ping")["status"] == "OK"
    end

    def seconds = Float(ENV.fetch("READYZ_TIMEOUT_SECONDS", 2), exception: false) || 2

    def run
      Timeout.timeout(seconds + 1) { yield ? "ok" : "fail" }
    rescue StandardError, Timeout::Error
      "fail"
    end
  end
end
