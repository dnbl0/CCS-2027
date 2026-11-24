# frozen_string_literal: true

require "rack/mock_request"

# Loads the pages that are slow on an empty cache (the home page asks Solr 53 times, Browse 85) inside the running server, soon
# after it starts and then every CACHE_WARM_MINUTES, so a visitor never waits seconds for them after a restart, a deploy or the
# daily expiry of what they keep (docs/configuration.md). It runs in the web process itself because the default cache is in that
# process's memory (CACHE_STORE=memory): a job, which runs in another process, would fill a different cache.
# Started from config/puma.rb; CACHE_WARM=off turns it off. Each page goes through the whole app, as a local request, so the
# pages decide what to cache and the warmer never needs to know.
module CacheWarmer
  PATHS = %w[/ /browse /browse/time /browse/places /browse/colours /themes /stories].freeze
  FIRST_RUN_SECONDS = 5
  USER_AGENT = "CCS cache warmer"

  module_function

  def enabled?(setting = ENV.fetch("CACHE_WARM", "on")) = setting != "off"

  def interval_minutes(setting = ENV.fetch("CACHE_WARM_MINUTES", 10)) = Integer(setting, exception: false)&.clamp(1, 1440) || 10

  # The thread that warms the pages now and then on a timer, or nil when turned off. One per process (Puma's worker or single server).
  def start(enabled: enabled?, minutes: interval_minutes)
    return unless enabled

    interval = minutes * 60
    Thread.new do
      Thread.current.name = "cache-warmer"
      sleep FIRST_RUN_SECONDS
      loop do
        warm
        sleep interval
      end
    end
  end

  # { path => HTTP status, or :error } for each page
  def warm(app: Rails.application)
    PATHS.index_with do |path|
      status, _headers, body = app.call(Rack::MockRequest.env_for(path, "HTTP_HOST" => host, "REMOTE_ADDR" => "127.0.0.1",
                                                                         "HTTP_USER_AGENT" => USER_AGENT))
      body.close if body.respond_to?(:close)
      status
    rescue StandardError => e
      Rails.logger.warn("[cache warmer] #{path}: #{e.class}: #{e.message}")
      :error
    end
  end

  # A host the app accepts: the first of RAILS_HOSTS, else the first allowed host (".example.edu" allows "example.edu"), else localhost
  def host(named_hosts = ENV.fetch("RAILS_HOSTS", ""), hosts: Rails.application.config.hosts)
    named = named_hosts.split(",").map(&:strip).reject(&:empty?).first
    named || hosts.grep(String).first&.delete_prefix(".").presence || "localhost"
  end
end
