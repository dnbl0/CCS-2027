# frozen_string_literal: true

require "monitor"

# Rack middleware (lib/middleware, required by config/initializers/bot_guard.rb), ahead of the static file server so it sees the asset files too (CCS-127, CCS-128). Three jobs, each switched
# by an environment variable (docs/seo-and-bot-controls.md):
#
#   1. 403 for a listed user agent (BotControls.blocked_user_agent?) asking for the asset files or the zip and CSV endpoints.
#   2. 429 with Retry-After once one IP address passes the limit for its kind of request in a minute (a fixed window). The
#      kinds: search, record, download, asset. Generous for a person, who makes a handful of requests a minute.
#   3. X-Robots-Tag on the response, from RobotsPolicy (a page can set request.env["ccs.robots"] itself, as a record page does).
#
# Counts live in this process (RATE_LIMIT_STORE=memory, the default) or in Rails.cache (=cache): with several processes or
# instances the memory store lets each have its own count, so the real limit is the limit times the number of processes. Use a
# shared cache store, or the CDN/WAF, for an exact one.
class BotGuard
  WINDOW = 60 # seconds
  DEFAULT_LIMITS = { "search" => 120, "record" => 240, "download" => 20, "asset" => 600 }.freeze
  RESERVED_CATALOG = %w[advanced facet range_limit suggest opensearch].freeze

  # Counts per key in this process. Expired windows are dropped when the table grows.
  class MemoryStore
    include MonitorMixin

    def initialize
      super()
      @counts = {}
    end

    # Adds one to the count for key in the current window; returns the new count
    def increment(key, expires_in:, now: Time.now.to_i)
      synchronize do
        purge(now) if @counts.size > 10_000
        count, expires = @counts[key]
        count, expires = 0, now + expires_in if expires.nil? || expires <= now
        @counts[key] = [ count + 1, expires ]
        count + 1
      end
    end

    def purge(now) = @counts.delete_if { |_key, (_count, expires)| expires <= now }
    def clear = synchronize { @counts.clear }
  end

  def self.store = (@store ||= MemoryStore.new)

  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    path = request.path
    return forbidden if BotControls.enabled? && guarded?(request) && BotControls.blocked_user_agent?(request.user_agent)

    limited = throttle(request)
    return limited if limited

    status, headers, body = @app.call(env)
    tag = env["ccs.robots"] || RobotsPolicy.directive(status.to_i >= 400 ? "/404" : path, query(request))
    headers["x-robots-tag"] = tag if tag && headers["x-robots-tag"].nil?
    [ status, headers, body ]
  end

  private

  # The query string's parameters; none for one that cannot be read (the app answers that request with a 400)
  def query(request)
    request.query_parameters
  rescue ActionController::BadRequest
    {}
  end

  # The asset files, and the zip and CSV endpoints
  def guarded?(request)
    path = request.path
    path.start_with?("/digital-assets/") || path.start_with?("/downloads") || path.match?(%r{\A/catalog/[^/]+/metadata\z})
  end

  def kind(request)
    path = request.path
    if path.start_with?("/digital-assets/") then "asset"
    elsif path.start_with?("/downloads") || path.match?(%r{\A/catalog/[^/]+/metadata\z}) then "download"
    elsif path.match?(%r{\A/catalog(\.\w+)?\z}) || path.start_with?("/catalog/facet/", "/catalog/range_limit", "/catalog/suggest") then "search"
    elsif path.start_with?("/stock/", "/branded-stock/") || record_path?(path) then "record"
    end
  end

  def record_path?(path)
    segment = path[%r{\A/catalog/([^/]+)(?:/citation)?\z}, 1]
    segment && RESERVED_CATALOG.exclude?(segment)
  end

  def throttle(request)
    return unless BotControls.on?("RATE_LIMIT", !Rails.env.test?)

    kind = kind(request)
    return unless kind

    ip = request.remote_ip.to_s
    return if BotControls.list("RATE_LIMIT_ALLOW_IPS").include?(ip)

    limit = Integer(ENV.fetch("RATE_LIMIT_#{kind.upcase}_PER_MINUTE", DEFAULT_LIMITS.fetch(kind)), exception: false) || DEFAULT_LIMITS.fetch(kind)
    now = Time.now.to_i
    window = now / WINDOW
    count = count(kind, ip, window)
    return if count.nil? || count <= limit

    too_many((window + 1) * WINDOW - now)
  end

  def count(kind, ip, window)
    key = "ccs-rate:#{kind}:#{ip}:#{window}"
    if ENV["RATE_LIMIT_STORE"] == "cache"
      Rails.cache.increment(key, 1, expires_in: WINDOW * 2)
    else
      self.class.store.increment(key, expires_in: WINDOW)
    end
  end

  def forbidden = respond(403, "Forbidden: automated access to these files is not permitted.\n")

  def too_many(retry_after)
    respond(429, "Too many requests. Please wait a moment and try again.\n", "retry-after" => [ retry_after, 1 ].max.to_s)
  end

  def respond(status, text, extra = {})
    [ status, { "content-type" => "text/plain; charset=utf-8", "cache-control" => "no-store", "x-robots-tag" => "noindex" }.merge(extra), [ text ] ]
  end
end
