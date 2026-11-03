require "test_helper"

class CircuitBreakerTest < ActiveSupport::TestCase
  Down = Class.new(StandardError)

  setup do
    @now = 0.0
    @breaker = CircuitBreaker.new(name: "dependency", failures: [ Down ], threshold: 3, reset_after: 10, clock: -> { @now })
  end

  def fail_once = assert_raises(Down) { @breaker.call { raise Down } }

  test "calls go through and return their value while it is closed" do
    assert_equal :answer, @breaker.call { :answer }
    assert_equal :closed, @breaker.state
  end

  test "it opens after the threshold of failures in a row, and then refuses at once without calling" do
    3.times { fail_once }
    called = false

    assert_equal :open, @breaker.state
    assert_raises(CircuitBreaker::OpenError) { @breaker.call { called = true } }
    assert_not called
  end

  test "a success in between resets the count" do
    2.times { fail_once }
    @breaker.call { :ok }
    2.times { fail_once }

    assert_equal :closed, @breaker.state
  end

  test "an error that is not a listed failure passes through and counts as the dependency answering" do
    2.times { fail_once }
    assert_raises(ArgumentError) { @breaker.call { raise ArgumentError } }
    2.times { fail_once }

    assert_equal :closed, @breaker.state
  end

  test "after the window one probe is let through; if it works the circuit closes" do
    3.times { fail_once }
    @now = 10.0

    assert_equal :half_open, @breaker.state
    assert_equal :back, @breaker.call { :back }
    assert_equal :closed, @breaker.state
  end

  test "a failed probe opens it again for a whole window" do
    3.times { fail_once }
    @now = 10.0
    fail_once

    assert_equal :open, @breaker.state
    @now = 19.0
    assert_equal :open, @breaker.state
    @now = 20.0
    assert_equal :half_open, @breaker.state
  end

  test "only one probe at a time: others are refused while it is running" do
    3.times { fail_once }
    @now = 10.0
    refused = nil

    @breaker.call { refused = assert_raises(CircuitBreaker::OpenError) { @breaker.call { :second } } }

    assert_match(/probing/, refused.message)
    assert_equal :closed, @breaker.state
  end

  test "reset! closes it" do
    3.times { fail_once }
    @breaker.reset!

    assert_equal :closed, @breaker.state
  end
end
