# frozen_string_literal: true

# The two probes for a load balancer or an orchestrator (CCS-146), and /up (Rails' own, the app booted):
#   /healthz  liveness: the process is running and answering. Touches nothing else, so it stays 200 while the database or Solr is
#             down; restart the instance only when this fails.
#   /readyz   readiness: the database, Solr and the migrations are all as needed (Readiness). 200, or 503 when the instance should
#             not be sent visitors. Send traffic by this one.
# JSON, never cached, no session or cookie, no detail (a state per check, nothing else), kept out of search results, and not
# counted by the rate limit (BotGuard only counts search, record, download and asset requests). Kept out of the request log by
# config/initializers/resilience.rb.
class HealthController < ActionController::API
  before_action :never_cache

  def live
    render json: { status: "ok" }
  end

  def ready
    result = Readiness.call
    render json: result.to_h, status: result.ready? ? :ok : :service_unavailable
  end

  private

  def never_cache
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
  end
end
