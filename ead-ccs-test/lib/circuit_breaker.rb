# frozen_string_literal: true

# A fail-fast window around a dependency that may be down (CCS-147, CCS-146). After THRESHOLD failures in a row the circuit
# opens: for RESET_AFTER seconds every call is refused at once (OpenError) instead of waiting out a connection or read timeout,
# so a dead dependency does not tie up every Puma thread. When the time is up one call is let through as a probe (half open):
# if it works the circuit closes, if it fails the window starts again. Plain Ruby, one instance per process (each instance of
# the app learns for itself; nothing is shared).
#
#   breaker = CircuitBreaker.new(name: "solr", failures: [ Errno::ECONNREFUSED ], threshold: 5, reset_after: 10)
#   breaker.call { connection.get("select") }
#
# Only the exceptions in failures: count. Any other exception passes through and counts as a success (the dependency answered).
class CircuitBreaker
  class OpenError < StandardError; end

  attr_reader :name

  # failures: exception classes that mean "the dependency is down or too slow"; clock: seconds on a monotonic clock (tests pass their own)
  def initialize(name:, failures:, threshold: 5, reset_after: 10, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
    @name = name
    @failures = failures
    @threshold = threshold
    @reset_after = reset_after
    @clock = clock
    @mutex = Mutex.new
    reset!
  end

  def call
    probing = admit!
    begin
      result = yield
    rescue *@failures
      record_failure(probing)
      raise
    rescue Exception # rubocop:disable Lint/RescueException -- every other exit means the dependency answered; release a probe
      record_success
      raise
    end
    record_success
    result
  end

  # :closed (calls go through), :open (refused) or :half_open (the window is up; one probe may go through)
  def state
    @mutex.synchronize { current_state }
  end

  def reset!
    @mutex.synchronize { @failure_count, @opened_at, @probing = 0, nil, false }
  end

  private

  # Raises OpenError when the call is refused; returns true when this call is the half-open probe
  def admit!
    @mutex.synchronize do
      case current_state
      when :closed then false
      when :half_open
        raise OpenError, "#{@name} circuit is open (probing)" if @probing

        @probing = true
      else raise OpenError, "#{@name} circuit is open"
      end
    end
  end

  def current_state
    return :closed unless @opened_at

    @clock.call - @opened_at >= @reset_after ? :half_open : :open
  end

  def record_failure(probing)
    @mutex.synchronize do
      @probing = false if probing
      @failure_count += 1
      @opened_at = @clock.call if probing || @failure_count >= @threshold
    end
  end

  def record_success
    @mutex.synchronize { @failure_count, @opened_at, @probing = 0, nil, false }
  end
end
