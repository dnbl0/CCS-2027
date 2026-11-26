# frozen_string_literal: true

require "test_helper"

# An optional part of a page that fails is logged; a bug (anything but an outage) is also reported to Rails.error, so it is not
# hidden behind an empty section
class DiscoveryLogFailureTest < ActiveSupport::TestCase
  class Recorder
    attr_reader :reports

    def initialize = @reports = []

    def report(error, **) = @reports << error
  end

  def reported
    recorder = Recorder.new
    Rails.error.subscribe(recorder)
    yield
    recorder.reports
  ensure
    Rails.error.unsubscribe(recorder)
  end

  test "a Solr outage is logged, not reported" do
    errors = reported { Discovery.log_failure("Similar records", Faraday::ConnectionFailed.new("down")) }
    assert_empty errors
  end

  test "a programming error is reported as a handled warning" do
    bug = NoMethodError.new("undefined method 'x' for nil")
    errors = reported { Discovery.log_failure("Similar records", bug) }
    assert_equal [ bug ], errors
  end
end
