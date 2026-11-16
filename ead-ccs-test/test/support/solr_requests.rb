# frozen_string_literal: true

# Answers every request to Solr with an empty result and keeps what was asked, so a test can look at what the app sends without a
# Solr core (the "rails" CI job has none). Unlike CannedSearch (which replaces Blacklight's repository), this sits at the RSolr
# client, below everything: the circuit breaker, the repository and the raw `connection.get` calls of the models all go through it.
module SolrRequests
  Request = Struct.new(:path, :params) do
    # The filter queries sent, as Solr receives them
    def fq = Array(params["fq"])
  end

  EMPTY = {
    "responseHeader" => { "status" => 0, "params" => {} },
    "response" => { "numFound" => 0, "start" => 0, "docs" => [] },
    "facet_counts" => { "facet_queries" => {}, "facet_fields" => {}, "facet_ranges" => {}, "facet_intervals" => {}, "facet_heatmaps" => {} },
    "stats" => { "stats_fields" => {} }
  }.freeze

  module Tap
    cattr_accessor :sent

    def execute(request_context)
      return super unless Tap.sent

      query = request_context[:data].is_a?(String) ? request_context[:data] : request_context[:query].to_s
      params = Rack::Utils.parse_query(query)
      Tap.sent << Request.new(request_context[:path], params)
      EMPTY.deep_dup
    end
  end
  RSolr::Client.prepend(Tap) unless RSolr::Client < Tap

  # Runs the block with Solr answered as above. Returns the requests, in the order sent.
  def capture_solr
    Tap.sent = []
    yield
    Tap.sent
  ensure
    Tap.sent = nil
  end
end
