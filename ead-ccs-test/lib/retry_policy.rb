# frozen_string_literal: true

# A bounded retry (CCS-147): at most `retries` more attempts, only for the exceptions in on:, only for a call that is safe to repeat
# (idempotent: a read), with a short randomised pause so that many threads do not retry in step. Used for Solr, where the retried
# error is "connection refused" (nothing was sent, so nothing can be done twice). A timeout is never retried: it would double the
# wait and add load to a dependency that is already slow.
class RetryPolicy
  def initialize(retries: 1, on: [], delay: 0.05, sleeper: Kernel.method(:sleep), random: Random)
    @retries = retries
    @on = on
    @delay = delay
    @sleeper = sleeper
    @random = random
  end

  def call(idempotent: true)
    attempts = 0
    begin
      attempts += 1
      yield
    rescue *@on
      raise if !idempotent || attempts > @retries

      @sleeper.call(@delay * (1 + @random.rand))
      retry
    end
  end
end
