# frozen_string_literal: true

require "json"

# The place errors go (CCS-147). Rails.error.report(...) and every unhandled exception reaches subscribers; this one writes a
# single JSON line to the Rails log: time, severity, whether the app handled it, the error class and (cut) message, where it came
# from, the request id, and the top frames of the backtrace inside the app. No parameters, cookies or query strings.
#
# To send errors to a service (Sentry, Honeybadger, Azure Application Insights, Datadog...) add its gem and subscribe its
# subscriber in config/initializers/resilience.rb next to this one: Rails.error.subscribe(TheirSubscriber.new). See
# docs/availability-reliability-scalability.md.
class ErrorLogSubscriber
  MESSAGE_LIMIT = 500
  FRAMES = 5

  # The interface of ActiveSupport::ErrorReporter subscribers
  def report(error, handled:, severity:, context:, source: nil)
    Rails.logger.public_send(severity == :warning ? :warn : :error, JSON.generate(line(error, handled, severity, context, source)))
  rescue StandardError
    nil # never let reporting an error raise another
  end

  private

  def line(error, handled, severity, context, source)
    {
      time: Time.now.utc.iso8601(3), level: severity.to_s, event: "error", handled: handled, error_class: error.class.name,
      message: error.message.to_s.truncate(MESSAGE_LIMIT), source: source, request_id: context[:request_id],
      method: context[:http_method], path: context[:path], backtrace: app_frames(error)
    }.compact
  end

  def app_frames(error)
    root = Rails.root.to_s
    (error.backtrace || []).select { |frame| frame.start_with?(root) }.first(FRAMES).map { |frame| frame.delete_prefix("#{root}/") }
  end
end
