ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # The "rails" CI job has no Solr (the system job does): a test that reads the Solr core at SOLR_URL skips itself when it
    # cannot be reached. Some test files define their own copy of this.
    def needs_solr
      Blacklight.default_index.connection.get("select", params: { q: "*:*", rows: 0 })
    rescue StandardError
      skip "needs the Solr core at SOLR_URL"
    end
  end
end
