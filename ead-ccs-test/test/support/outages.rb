# Stand-ins for the dependencies being down, for the resilience tests (no Solr or database stop is needed, so they run in CI). Each
# block puts everything back, even if the block fails.
module Outages
  # Raises as the database does when it cannot be reached, for every query while active
  module DatabaseDown
    cattr_accessor :active, default: false

    %i[internal_exec_query internal_execute execute exec_query].each do |name|
      define_method(name) do |*args, **options, &block|
        raise ActiveRecord::ConnectionNotEstablished, "the database is down (test)" if DatabaseDown.active

        super(*args, **options, &block)
      end
    end
  end
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(DatabaseDown) unless ActiveRecord::ConnectionAdapters::PostgreSQLAdapter < DatabaseDown

  # Every request to Solr is refused, as when nothing is listening (goes through Blacklight's repository, the circuit breaker and the retry)
  module SolrDown
    cattr_accessor :active, default: false
    cattr_accessor :requests, default: 0

    def execute(*)
      return super unless SolrDown.active

      SolrDown.requests += 1
      raise Errno::ECONNREFUSED, "connect(2) (test)"
    end
  end
  RSolr::Client.prepend(SolrDown) unless RSolr::Client < SolrDown

  def with_database_down
    DatabaseDown.active = true
    yield
  ensure
    DatabaseDown.active = false
  end

  def with_solr_down
    SolrGuard.reset!
    SolrDown.active = true
    SolrDown.requests = 0
    yield
  ensure
    SolrDown.active = false
    SolrGuard.reset!
  end

  # The test environment shows Rails' detailed exception pages; production hands the failed request to config.exceptions_app.
  def as_production
    env = Rails.application.env_config
    before = env.values_at("action_dispatch.show_exceptions", "action_dispatch.show_detailed_exceptions")
    env["action_dispatch.show_exceptions"] = :all
    env["action_dispatch.show_detailed_exceptions"] = false
    yield
  ensure
    env["action_dispatch.show_exceptions"], env["action_dispatch.show_detailed_exceptions"] = before
  end

  # What each error page answers: the exception that Rails turns into that status
  ERRORS = {
    "400" => -> { ActionController::BadRequest.new("bad") }, "404" => -> { ActionController::RoutingError.new("Not Found") },
    "406" => -> { ActionController::UnknownFormat.new }, "422" => -> { ActionController::InvalidAuthenticityToken.new },
    "429" => -> { ActionController::TooManyRequests.new }, "500" => -> { RuntimeError.new("boom") },
    "503" => -> { ActiveRecord::ConnectionNotEstablished.new("the database is down (test)") }
  }.freeze

  # Runs the block (which asks for /help) with that page raising the exception for the status, as production shows errors
  def with_error_page(code)
    exception = ERRORS.fetch(code).call
    original = PagesController.instance_method(:help)
    PagesController.define_method(:help) { raise exception }
    as_production { yield }
  ensure
    PagesController.define_method(:help, original)
  end
end
