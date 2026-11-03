require "test_helper"
require_relative "../support/outages"

class SolrGuardTest < ActiveSupport::TestCase
  include Outages

  setup { SolrGuard.reset! }
  teardown { SolrGuard.reset! }

  test "a refused connection is tried twice, then raised" do
    attempts = 0
    assert_raises(Errno::ECONNREFUSED) { SolrGuard.run { attempts += 1; raise Errno::ECONNREFUSED } }
    assert_equal 2, attempts
  end

  test "a timeout is tried once only" do
    attempts = 0
    assert_raises(Blacklight::Exceptions::RepositoryTimeout) { SolrGuard.run { attempts += 1; raise Blacklight::Exceptions::RepositoryTimeout } }
    assert_equal 1, attempts
  end

  test "after the threshold of failures Solr is not asked at all, and the refusal is a Blacklight ECONNREFUSED" do
    asked = 0
    5.times { assert_raises(Errno::ECONNREFUSED) { SolrGuard.run { asked += 1; raise Errno::ECONNREFUSED } } }
    before = asked

    error = assert_raises(SolrGuard::Unavailable) { SolrGuard.run { asked += 1 } }

    assert_kind_of Blacklight::Exceptions::ECONNREFUSED, error
    assert_equal before, asked
  end

  test "a bad query (Solr's 400) is not an outage and does not count" do
    10.times { assert_raises(Blacklight::Exceptions::InvalidRequest) { SolrGuard.run { raise Blacklight::Exceptions::InvalidRequest } } }

    assert_equal :closed, SolrGuard.breaker.state
  end

  test "through Blacklight's repository: a dead Solr costs a few requests, then none" do
    with_solr_down do
      repository = Blacklight.default_index
      10.times { assert_raises(Blacklight::Exceptions::ECONNREFUSED) { repository.search(params: { q: "x" }) } }

      assert_equal :open, SolrGuard.breaker.state
      assert_operator SolrDown.requests, :<=, 10, "5 failures x (1 try + 1 retry) at most"
    end
  end
end
