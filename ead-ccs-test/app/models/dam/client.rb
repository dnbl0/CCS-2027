# frozen_string_literal: true

require "net/http"

module Dam
  # The Nexus DAM's API (Acquia DAM v2, api.widencollective.com). Read only: it searches assets and nothing else.
  #
  # A search is read in offset pages of 100, sorted by creation date, with only the parts of each asset the sync uses expanded.
  # Offset paging, not the DAM's scroll: the DAM sometimes answers a scroll request with HTTP 500 after moving the scroll on, so
  # retrying it silently skips 100 assets (seen 2026-11-17). An offset page asks for the same assets however often it is
  # retried. Offset paging stops at 10,000 results, so a bigger search is split into smaller date ranges first (Dam::Sync).
  #
  # Rate limiting (429), server errors and dropped connections are retried with a growing wait. The token is read from ENV
  # (DAM_API_TOKEN) and only ever sent in the Authorization header.
  class Client
    BASE_URL = "https://api.widencollective.com/v2"
    EXPAND = "metadata,file_properties,embeds"
    PAGE_SIZE = 100
    # The DAM refuses limit + offset above this
    OFFSET_LIMIT = 10_000
    SORT = "created_date"
    ATTEMPTS = 6
    RETRIED = [ 429, 500, 502, 503, 504 ].freeze
    TRANSPORT_ERRORS = [ Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError, EOFError, OpenSSL::SSL::SSLError ].freeze

    # A search that returned fewer distinct assets than the DAM counted: an asset was edited while it was read (and moved
    # out of the date range), so the pages shifted. Reading it again gives the right set.
    class ShortRead < Error; end

    def self.configured? = ENV["DAM_API_TOKEN"].present?

    def self.from_env
      raise Error, "DAM_API_TOKEN is not set (read it from the Keychain: see docs/dam-sync.md)" unless configured?

      new(token: ENV["DAM_API_TOKEN"], base_url: ENV.fetch("DAM_API_URL", BASE_URL))
    end

    # The DAM's search query for assets last edited between two times (both included)
    def self.edited_between(from, to) = "lastEditDate:[#{from.utc.iso8601} to #{to.utc.iso8601}]"

    # transport: ->(uri, headers) { [status, body] }, for tests; sleeper: ->(seconds) { }, for tests
    def initialize(token:, base_url: BASE_URL, transport: nil, sleeper: nil, logger: Rails.logger)
      @token = token
      @base_url = base_url.chomp("/")
      @transport = transport || method(:net_http)
      @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      @logger = logger
    end

    # How many assets a search matches
    def count(query) = search(query, offset: 0, limit: 1, expand: false)["total_count"].to_i

    # Yields each page's assets (an Array of Hashes) with the number read so far and the total, and returns the number of
    # distinct assets read. expand: false reads ids and dates only (the weekly reconcile). A search of more than OFFSET_LIMIT
    # assets is an error (split it); one that returns fewer distinct assets than it counted raises ShortRead.
    def each_page(query:, expand: true)
      first = search(query, offset: 0, limit: PAGE_SIZE, expand: expand)
      total = first["total_count"].to_i
      raise Error, "#{total} assets match #{query.inspect}: more than #{OFFSET_LIMIT} cannot be paged; split the search" if total > OFFSET_LIMIT

      ids = Set.new
      page = first
      offset = 0
      loop do
        items = Array(page["items"])
        break if items.empty?

        ids.merge(items.map { |item| item["id"] })
        yield items, offset + items.size, total
        offset += PAGE_SIZE
        break if offset >= total

        page = search(query, offset: offset, limit: PAGE_SIZE, expand: expand)
      end
      raise ShortRead, "#{query.inspect} returned #{ids.size} of the #{total} assets the DAM counted" if ids.size < total

      ids.size
    end

    private

    def search(query, offset:, limit:, expand:)
      params = { query: query.presence, offset: offset, limit: limit, sort: SORT, expand: (EXPAND if expand) }.compact
      page = get("/assets/search", params)
      raise Error, "the DAM cannot read the query #{query.inspect}: #{page['query_explained']}" if page["query_syntax_ok"] == false

      page
    end

    # GET a path; the parsed JSON
    def get(path, params)
      uri = URI("#{@base_url}#{path}")
      uri.query = URI.encode_www_form(params)
      ATTEMPTS.times do |index|
        attempt = index + 1
        begin
          status, body = @transport.call(uri, { "Authorization" => "Bearer #{@token}", "Accept" => "application/json" })
        rescue *TRANSPORT_ERRORS => e
          status, reason = nil, e.class.name
        end
        return JSON.parse(body) if status && status < 300
        raise Error, "the DAM answered HTTP #{status} for #{path}" if status && !RETRIED.include?(status)

        reason ||= "HTTP #{status}"
        break if attempt == ATTEMPTS

        wait = 2**attempt
        @logger.warn("[dam] #{path}: #{reason}; retry #{attempt}/#{ATTEMPTS - 1} in #{wait}s")
        @sleeper.call(wait)
      end
      raise Error, "the DAM was still failing after #{ATTEMPTS} attempts (#{path})"
    end

    def net_http(uri, headers)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 15, read_timeout: 90) do |http|
        response = http.request(Net::HTTP::Get.new(uri, headers))
        [ response.code.to_i, response.body ]
      end
    end
  end
end
