require "test_helper"

class DamClientTest < ActiveSupport::TestCase
  # Answers requests in turn from a list of [status, body] (or an exception), recording each URI and header set
  class Transport
    attr_reader :requests

    def initialize(*responses) = (@responses = responses) && (@requests = [])

    def call(uri, headers)
      @requests << [ uri, headers ]
      response = @responses.shift or raise "no response left for #{uri}"
      raise response if response.is_a?(Exception)

      response
    end
  end

  def client(transport, waits = [])
    Dam::Client.new(token: "t0k3n", base_url: "https://dam.test/v2", transport: transport, sleeper: ->(seconds) { waits << seconds },
                    logger: Logger.new(IO::NULL))
  end

  def page(items, total:, scroll: "s1") = [ 200, { "items" => items, "total_count" => total, "scroll_id" => scroll }.to_json ]

  test "a search is read with a scroll, 100 a page, expanding only what the sync uses, with the token in the header" do
    transport = Transport.new(page([ { "id" => "a" } ], total: 2), page([ { "id" => "b" } ], total: 2), page([], total: 2))
    ids = []
    seen = client(transport).each_page(query: "lastEditDate:[x to y]") { |items, _seen, _total| ids.concat(items.map { |i| i["id"] }) }

    assert_equal %w[a b], ids
    assert_equal 2, seen
    first, headers = transport.requests.first
    assert_equal "/v2/assets/search", first.path
    params = URI.decode_www_form(first.query).to_h
    assert_equal({ "scroll" => "true", "limit" => "100", "query" => "lastEditDate:[x to y]", "expand" => "metadata,file_properties,embeds" }, params)
    assert_equal "Bearer t0k3n", headers["Authorization"]
    assert_equal "/v2/assets/search/scroll", transport.requests.second.first.path
    assert_equal "s1", URI.decode_www_form(transport.requests.second.first.query).to_h["scroll_id"]
  end

  test "rate limiting, server errors and dropped connections are retried with a growing wait" do
    transport = Transport.new([ 429, "" ], [ 503, "" ], Net::ReadTimeout.new, page([ { "id" => "a" } ], total: 1), page([], total: 1))
    waits = []
    client(transport, waits).each_page { |_items, _seen, _total| nil }

    assert_equal [ 2, 4, 8 ], waits
  end

  test "it gives up after six attempts" do
    transport = Transport.new(*Array.new(6) { [ 500, "" ] })
    error = assert_raises(Dam::Error) { client(transport).each_page { nil } }
    assert_match "6 attempts", error.message
  end

  test "an error that is not worth retrying stops at once, without the token in the message" do
    error = assert_raises(Dam::Error) { client(Transport.new([ 401, "" ])).each_page { nil } }
    assert_match "HTTP 401", error.message
    assert_no_match "t0k3n", error.message
  end

  test "a scroll that expires part way, or ends short of the count, is an error" do
    expired = Transport.new(page([ { "id" => "a" } ], total: 2), [ 404, "" ])
    assert_raises(Dam::Error) { client(expired).each_page { nil } }

    short = Transport.new(page([ { "id" => "a" } ], total: 10), page([], total: 10))
    assert_raises(Dam::Error) { client(short).each_page { nil } }
  end

  test "the DAM's usual small gap between its count and what it returns is logged, not an error" do
    items = Array.new(100) { |i| { "id" => "a#{i}" } }
    transport = Transport.new(page(items, total: 10_000), *Array.new(98) { page(items, total: 10_000) }, page([], total: 10_000))
    assert_equal 9_900, client(transport).each_page { nil }
  end

  test "a query the DAM cannot read is an error" do
    bad = Transport.new([ 200, { "query_syntax_ok" => false, "query_explained" => "near *" }.to_json ])
    assert_raises(Dam::Error) { client(bad).each_page(query: "x:*") { nil } }
  end

  test "edited_between is the DAM's last-edit-date range, in UTC" do
    from = Time.utc(2026, 11, 14)
    assert_equal "lastEditDate:[2026-11-14T00:00:00Z to 2026-11-18T00:00:00Z]", Dam::Client.edited_between(from, from + 4.days)
  end
end
