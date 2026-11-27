ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # What the circuit breaker learnt in one test (a Solr that was down) must not reach the next
    setup { SolrGuard.reset! }

    # Nor the list of suppressed records (CCS-112): a test's rolled-back rows must not leave their ids behind
    setup { SuppressedRecord.forget! }

    # The Full text (PDF) search is offered only when the core is known to have its field; tests start with it off, and never ask Solr
    setup { PdfTextIndex.force(nil) }
    # The CJK search (CCS-56) is offered only when the core is known to have its fields; tests start with it off, and never ask Solr
    setup { CjkIndex.force(nil) }
    teardown { SuppressedRecord.forget! }

    # Add more helper methods to be used by all tests here...

    # The "rails" CI job has no Solr (the system job does): a test that reads the Solr core at SOLR_URL skips itself when it
    # cannot be reached.
    def needs_solr
      Blacklight.default_index.connection.get("select", params: { q: "*:*", rows: 0 })
    rescue StandardError
      skip "needs the Solr core at SOLR_URL"
    end
  end
end
