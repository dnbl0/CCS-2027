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

  def page(ids, total:) = [ 200, { "items" => ids.map { |id| { "id" => id } }, "total_count" => total }.to_json ]
  def params(request) = URI.decode_www_form(request.first.query).to_h

  test "a search is read in offset pages of 100, sorted, expanding only what the sync uses, with the token in the header" do
    first = (1..100).map { |n| "a#{n}" }
    transport = Transport.new(page(first, total: 150), page((101..150).map { |n| "a#{n}" }, total: 150))
    ids = []
    read = client(transport).each_page(query: "lastEditDate:[x to y]") { |items, _seen, _total| ids.concat(items.map { |i| i["id"] }) }

    assert_equal 150, read
    assert_equal 150, ids.uniq.size
    assert_equal({ "query" => "lastEditDate:[x to y]", "offset" => "0", "limit" => "100", "sort" => "created_date", "expand" => "metadata,file_properties,embeds" },
                 params(transport.requests.first))
    assert_equal "100", params(transport.requests.second)["offset"]
    assert_equal "/v2/assets/search", transport.requests.second.first.path
    assert_equal "Bearer t0k3n", transport.requests.first.last["Authorization"]
  end

  test "rate limiting, server errors and dropped connections are retried with a growing wait, asking for the same page again" do
    transport = Transport.new([ 429, "" ], [ 500, "" ], Net::ReadTimeout.new, page(%w[a], total: 1))
    waits = []
    client(transport, waits).each_page(query: "q") { nil }

    assert_equal [ 2, 4, 8 ], waits
    assert_equal [ "0" ], transport.requests.map { |request| params(request)["offset"] }.uniq
  end

  test "it gives up after six attempts" do
    transport = Transport.new(*Array.new(6) { [ 500, "" ] })
    error = assert_raises(Dam::Error) { client(transport).each_page(query: "q") { nil } }
    assert_match "6 attempts", error.message
  end

  test "an error that is not worth retrying stops at once, without the token in the message" do
    error = assert_raises(Dam::Error) { client(Transport.new([ 401, "" ])).each_page(query: "q") { nil } }
    assert_match "HTTP 401", error.message
    assert_no_match "t0k3n", error.message
  end

  test "fewer distinct assets than counted is a short read, to be read again" do
    shifted = Transport.new(page((1..100).map { |n| "a#{n}" }, total: 200), page((100..199).map { |n| "a#{n}" }, total: 200))
    assert_raises(Dam::Client::ShortRead) { client(shifted).each_page(query: "q") { nil } }
  end

  test "a search bigger than offset paging allows must be split" do
    error = assert_raises(Dam::Error) { client(Transport.new(page(%w[a], total: 10_001))).each_page(query: "q") { nil } }
    assert_match "split", error.message
  end

  test "count asks for one asset and reads the total" do
    transport = Transport.new(page(%w[a], total: 61_924))
    assert_equal 61_924, client(transport).count("q")
    assert_equal "1", params(transport.requests.first)["limit"]
    assert_nil params(transport.requests.first)["expand"]
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
