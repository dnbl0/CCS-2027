# Reliability (CCS-147, CCS-146): every Solr request through the circuit breaker and one retry (lib/solr_guard.rb), and the errors
# the app handles written as structured log lines (lib/error_log_subscriber.rb). docs/availability-reliability-scalability.md.
require Rails.root.join("lib/middleware/request_limits")
require Rails.root.join("lib/middleware/request_context")

Rails.application.config.to_prepare do
  Blacklight::Solr::Repository.prepend(SolrGuard) unless Blacklight::Solr::Repository < SolrGuard
end

# Request id on every error report, and a cap on the size of a request (before anything is parsed)
Rails.application.config.middleware.insert_after ActionDispatch::RequestId, RequestContext
Rails.application.config.middleware.insert_before ActionDispatch::Static, RequestLimits

# The probes come every few seconds: not worth a log line each (a failing probe shows in the 5xx counts and in ErrorLogSubscriber)
Rails.application.config.middleware.insert_before Rails::Rack::Logger, Rails::Rack::SilenceRequest, path: %r{\A/(healthz|readyz)\z}

Rails.application.config.after_initialize do
  Rails.error.subscribe(ErrorLogSubscriber.new) unless Rails.env.test?
end

# A database that cannot be reached, and a Solr that cannot be reached or answered in time, are "try again shortly" (503), not a
# server error (500). Pages that handle Solr themselves (CatalogController#search_unavailable) keep doing so.
ActionDispatch::ExceptionWrapper.rescue_responses.merge!(
  "ActiveRecord::ConnectionNotEstablished" => :service_unavailable,
  "ActiveRecord::ConnectionTimeoutError" => :service_unavailable,
  "ActiveRecord::DatabaseConnectionError" => :service_unavailable,
  "ActiveRecord::AdapterTimeout" => :service_unavailable,
  "ActiveRecord::QueryCanceled" => :service_unavailable,
  "ActiveRecord::NoDatabaseError" => :service_unavailable,
  "PG::ConnectionBad" => :service_unavailable,
  "Blacklight::Exceptions::ECONNREFUSED" => :service_unavailable,
  "Blacklight::Exceptions::RepositoryTimeout" => :service_unavailable,
  "SolrGuard::Unavailable" => :service_unavailable,
  "Faraday::ConnectionFailed" => :service_unavailable,
  "Faraday::TimeoutError" => :service_unavailable
)
