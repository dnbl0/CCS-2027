# frozen_string_literal: true

require "net/http"

module Dam
  # The Nexus DAM's API (Acquia DAM v2, api.widencollective.com). Read only: it searches assets and nothing else.
  # A search is read with a scroll (offset paging stops at 10,000 results), 100 assets a page, with only the parts of each
  # asset the sync uses expanded. Rate limiting (429), server errors and dropped connections are retried with a growing wait.
  # The token is read from ENV (DAM_API_TOKEN) and only ever sent in the Authorization header.
  class Client
    BASE_URL = "https://api.widencollective.com/v2"
    EXPAND = "metadata,file_properties,embeds"
    PAGE_SIZE = 100
    ATTEMPTS = 6
    RETRIED = [ 429, 500, 502, 503, 504 ].freeze
    TRANSPORT_ERRORS = [ Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError, EOFError, OpenSSL::SSL::SSLError ].freeze

    def self.configured? = ENV["DAM_API_TOKEN"].present?

    def self.from_env
      raise Error, "DAM_API_TOKEN is not set (read it from the Keychain: see docs/dam-sync.md)" unless configured?

      new(token: ENV["DAM_API_TOKEN"], base_url: ENV.fetch("DAM_API_URL", BASE_URL))
    end

    # transport: ->(uri, headers) { [status, body] }, for tests; sleeper: ->(seconds) { }, for tests
    def initialize(token:, base_url: BASE_URL, transport: nil, sleeper: nil, logger: Rails.logger)
      @token = token
      @base_url = base_url.chomp("/")
      @transport = transport || method(:net_http)
      @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      @logger = logger
    end

    # Yields each page's assets (an Array of Hashes) for a DAM search query (nil: every asset), and returns the number read.
    # expand: false reads ids and dates only (the weekly reconcile). Raises Dam::Error when fewer assets arrive than the DAM counted.
    def each_page(query: nil, expand: true)
      params = { scroll: true, limit: PAGE_SIZE, query: query.presence, expand: (EXPAND if expand) }.compact
      page = get("/assets/search", params)
      raise Error, "the DAM cannot read the query #{query.inspect}: #{page['query_explained']}" if page["query_syntax_ok"] == false

      total = page["total_count"].to_i
      seen = 0
      while page && Array(page["items"]).any?
        seen += page["items"].size
        yield page["items"], seen, total
        page = get("/assets/search/scroll", { scroll_id: page["scroll_id"], expand: (EXPAND if expand) }.compact)
        raise Error, "the DAM dropped the search after #{seen} of #{total} assets (the scroll expired)" if page.nil?
      end
      check_count(seen, total, query)
      seen
    end

    # The DAM's search query for assets last edited between two times (both included)
    def self.edited_between(from, to) = "lastEditDate:[#{from.utc.iso8601} to #{to.utc.iso8601}]"

    # The DAM's total_count runs a little ahead of what a scroll returns (on 2026-11-17: 175,308 counted, 175,108 returned, no
    # duplicates, the same each time), so a gap of up to this share is logged; a bigger one means the read went wrong.
    SHORTFALL_ALLOWED = 0.01

    private

    def check_count(seen, total, query)
      return if seen >= total

      message = "the search #{query.inspect} returned #{seen} of the #{total} assets the DAM counted"
      raise Error, message if total - seen > (total * SHORTFALL_ALLOWED).ceil

      @logger.warn("[dam] #{message} (within the DAM's usual gap)")
    end

    # GET a path; the parsed JSON, or nil for 404 (a scroll that has expired)
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
        return nil if status == 404
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
