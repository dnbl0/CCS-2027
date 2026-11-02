# Counts the work a block of code makes the app do: SQL statements that reach the database (not schema or transaction
# bookkeeping, nor repeats the query cache answers) and requests to Solr.
# Used by the performance budget tests and by bin/perf.
module RequestCounter
  Counts = Struct.new(:sql, :solr, :statements, :solr_requests)

  # Notes each request RSolr sends, without changing it
  module SolrTap
    def execute(request_context)
      RequestCounter.record_solr(request_context[:uri].to_s)
      super
    end
  end

  IGNORED_SQL = /\A(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)|pg_|SCHEMA|schema_migrations/i

  class << self
    attr_accessor :solr_log

    def record_solr(uri)
      solr_log&.push(uri)
    end

    def install
      return if RSolr::Client.ancestors.include?(SolrTap)

      RSolr::Client.prepend(SolrTap)
    end
  end

  def count_requests
    RequestCounter.install
    statements = []
    RequestCounter.solr_log = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
      next if payload[:cached] || payload[:name] == "SCHEMA" || payload[:sql].match?(IGNORED_SQL) # a repeat the query cache answered is not a database trip

      statements << payload[:sql]
    end
    ActiveRecord::Base.connection_pool.clear_query_cache # a test keeps the query cache between requests; a visitor's request starts empty
    yield
    Counts.new(statements.size, RequestCounter.solr_log.size, statements, RequestCounter.solr_log)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    RequestCounter.solr_log = nil
  end
end
