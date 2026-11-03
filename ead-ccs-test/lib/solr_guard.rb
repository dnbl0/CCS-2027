# frozen_string_literal: true

require "net/http"
require "faraday"

# Every Solr request the site makes goes through this (CCS-147, CCS-146): a circuit breaker, so that a dead Solr costs one failed
# request per window instead of a timeout per request, and one retry of a refused connection. Prepended to
# Blacklight::Solr::Repository (config/initializers/resilience.rb); BrowseMenu uses SolrGuard.run for its own request.
# All of the site's Solr calls are reads, so they are all safe to repeat. Settings (environment, safe defaults): SOLR_RETRIES (1),
# SOLR_BREAKER_THRESHOLD (5 failures in a row), SOLR_BREAKER_RESET_SECONDS (10). The timeouts are in config/blacklight.yml.
module SolrGuard
  # Refused without trying: the circuit is open. A Blacklight::Exceptions::ECONNREFUSED, so every page that answers "search is unavailable" does.
  class Unavailable < Blacklight::Exceptions::ECONNREFUSED; end

  # Solr is down or too slow. (A 400 from Solr is a bad query, not an outage: it does not count.)
  FAILURES = [
    Blacklight::Exceptions::ECONNREFUSED, Blacklight::Exceptions::RepositoryTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET,
    Errno::EHOSTUNREACH, SocketError, Net::OpenTimeout, Net::ReadTimeout, Faraday::ConnectionFailed, Faraday::TimeoutError,
    RSolr::Error::ConnectionRefused, RSolr::Error::Timeout
  ].freeze
  # The connection was never made, so nothing reached Solr: safe to try once more. Not the timeouts.
  RETRYABLE = [ Errno::ECONNREFUSED, Faraday::ConnectionFailed, RSolr::Error::ConnectionRefused ].freeze

  class << self
    def breaker
      @breaker ||= CircuitBreaker.new(name: "solr", failures: FAILURES, threshold: integer("SOLR_BREAKER_THRESHOLD", 5),
                                      reset_after: integer("SOLR_BREAKER_RESET_SECONDS", 10))
    end

    def policy
      @policy ||= RetryPolicy.new(retries: integer("SOLR_RETRIES", 1), on: RETRYABLE)
    end

    # Forgets what was learnt (tests, and after a settings change)
    def reset!
      @breaker = @policy = nil
    end

    def run(idempotent: true, &block)
      breaker.call { policy.call(idempotent: idempotent, &block) }
    rescue CircuitBreaker::OpenError => e
      raise Unavailable, e.message
    end

    private

    def integer(name, default) = Integer(ENV.fetch(name, default), exception: false) || default
  end

  def send_and_receive(...) = SolrGuard.run { super }

  def suggestions(...) = SolrGuard.run { super }
end
