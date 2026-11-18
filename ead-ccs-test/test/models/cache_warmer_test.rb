require "test_helper"

# The cache warmer: the pages that need many Solr requests on an empty cache (home 53, Browse 85) are loaded by the server itself
# after it starts and every few minutes, so no visitor waits seconds for them after a restart, a deploy or a daily expiry.
class CacheWarmerTest < ActiveSupport::TestCase
  test "every page it warms is a page of the site" do
    CacheWarmer::PATHS.each do |path|
      assert Rails.application.routes.recognize_path(path, method: :get), path
    end
  end

  test "warm loads each page through the whole app and reports its status, without raising when Solr is down" do
    statuses = CacheWarmer.warm
    assert_equal CacheWarmer::PATHS, statuses.keys
    statuses.each { |path, status| assert_includes [ 200, 503 ], status, path }
  end

  test "a page that fails is reported as an error and the others are still loaded" do
    calls = []
    app = lambda do |env|
      calls << env["PATH_INFO"]
      raise "boom" if env["PATH_INFO"] == "/browse"

      [ 200, {}, [ "" ] ]
    end
    statuses = CacheWarmer.warm(app: app)
    assert_equal CacheWarmer::PATHS, calls
    assert_equal :error, statuses["/browse"]
    assert_equal 200, statuses["/"]
  end

  test "it asks with a host the app accepts and as a local request" do
    env = nil
    CacheWarmer.warm(app: ->(e) { env ||= e; [ 200, {}, [ "" ] ] })
    assert_equal CacheWarmer.host, env["HTTP_HOST"]
    assert_equal "127.0.0.1", env["REMOTE_ADDR"]

    assert_equal "collections.example.edu", CacheWarmer.host("collections.example.edu, other.example.edu")
    assert_equal "localhost", CacheWarmer.host("", hosts: [])
    assert_equal "unimelb.edu.au", CacheWarmer.host("", hosts: [ ".unimelb.edu.au" ])
  end

  test "it is on unless CACHE_WARM is off, and runs every CACHE_WARM_MINUTES (10 by default)" do
    assert CacheWarmer.enabled?("on")
    assert_not CacheWarmer.enabled?("off")
    assert_equal 10, CacheWarmer.interval_minutes(10)
    assert_equal 30, CacheWarmer.interval_minutes("30")
    assert_equal 10, CacheWarmer.interval_minutes("soon")
    assert_nil CacheWarmer.start(enabled: false)
  end
end
