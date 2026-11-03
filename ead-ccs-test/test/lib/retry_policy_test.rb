require "test_helper"

class RetryPolicyTest < ActiveSupport::TestCase
  Refused = Class.new(StandardError)
  Slow = Class.new(StandardError)

  setup do
    @pauses = []
    @policy = RetryPolicy.new(retries: 1, on: [ Refused ], delay: 0.1, sleeper: ->(seconds) { @pauses << seconds }, random: Struct.new(:x) { def rand = 0.5 }.new)
  end

  def attempts_until(error_count, error: Refused)
    attempts = 0
    result = @policy.call do
      attempts += 1
      raise error if attempts <= error_count

      :done
    end
    [ attempts, result ]
  end

  test "a call that works is made once, without a pause" do
    assert_equal [ 1, :done ], attempts_until(0)
    assert_empty @pauses
  end

  test "a listed failure is tried once more, after a short randomised pause" do
    assert_equal [ 2, :done ], attempts_until(1)
    assert_in_delta 0.15, @pauses.first
  end

  test "it gives up after the retries, raising the last error: no retry storm" do
    attempts = 0
    assert_raises(Refused) { @policy.call { attempts += 1; raise Refused } }
    assert_equal 2, attempts
  end

  test "an error that is not listed (a timeout) is never retried" do
    attempts = 0
    assert_raises(Slow) { @policy.call { attempts += 1; raise Slow } }
    assert_equal 1, attempts
  end

  test "a call that is not idempotent is never retried" do
    attempts = 0
    assert_raises(Refused) { @policy.call(idempotent: false) { attempts += 1; raise Refused } }
    assert_equal 1, attempts
  end
end
