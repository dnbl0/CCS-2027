require "test_helper"
require_relative "../support/solr_requests"

# CCS-112: the one place that keeps a suppressed record out of Solr's answers (lib/suppressed_solr_filter.rb).
class SuppressedSolrFilterTest < ActiveSupport::TestCase
  include SolrRequests

  FILTER = "-{!terms f=id}emu-1".freeze

  setup { SuppressedRecord.forget! }
  teardown { SuppressedRecord.forget! }

  def connection = Blacklight.default_index.connection

  test "a search asked of the client carries the filter, whatever the form of its parameters" do
    SuppressedRecord.suppress!("emu-1", reason: "r")

    sent = capture_solr do
      connection.get("select", params: { q: "x" })
      connection.get("select", params: { "q" => "x", "fq" => "a:b" })
      connection.get("select", params: { q: "x", fq: [ "a:b", "c:d" ] })
      connection.send_and_receive("select", method: :post, data: { q: "x", fq: "a:b" })
    end

    assert_equal [ [ FILTER ], [ "a:b", FILTER ], [ "a:b", "c:d", FILTER ], [ "a:b", FILTER ] ], sent.map(&:fq)
  end

  test "nothing is added while no record is suppressed" do
    sent = capture_solr { connection.get("select", params: { q: "x", fq: "a:b" }) }

    assert_equal [ [ "a:b" ] ], sent.map(&:fq)
  end

  test "admin, update and suggest requests are left alone" do
    SuppressedRecord.suppress!("emu-1", reason: "r")

    sent = capture_solr do
      connection.get("admin/ping")
      connection.get("suggest", params: { q: "x" })
      connection.get("update", params: { commit: true })
    end

    assert_equal [ [], [], [] ], sent.map(&:fq)
  end

  test "the caller's own parameters are not changed" do
    SuppressedRecord.suppress!("emu-1", reason: "r")
    params = { q: "x", fq: [ "a:b" ] }
    capture_solr { connection.get("select", params: params) }

    assert_equal({ q: "x", fq: [ "a:b" ] }, params)
  end

  test "a long list is sent as a POST, so the address does not pass Solr's limit" do
    200.times { |n| SuppressedRecord.suppress!("emu-#{n + 1000}", reason: "r") }

    sent = capture_solr { connection.get("select", params: { q: "x" }) }

    assert_equal 1, sent.first.fq.size
    assert_operator sent.first.fq.first.bytesize, :>, SuppressedSolrFilter::LONG
    assert_equal "x", sent.first.params["q"]
  end
end
