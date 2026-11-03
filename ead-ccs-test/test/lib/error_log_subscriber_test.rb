require "test_helper"
require "stringio"

class ErrorLogSubscriberTest < ActiveSupport::TestCase
  setup do
    @io = StringIO.new
    @original = Rails.logger
    Rails.logger = Logger.new(@io, formatter: proc { |severity, _time, _program, message| "#{severity}|#{message}\n" })
    @subscriber = ErrorLogSubscriber.new
  end

  teardown { Rails.logger = @original }

  def line = JSON.parse(@io.string.lines.last.split("|", 2).last)

  test "an error becomes one JSON line with the request id, and no query string" do
    error = RuntimeError.new("boom")
    error.set_backtrace([ Rails.root.join("app/models/list.rb:10:in 'x'").to_s, "/gems/other.rb:1" ])

    @subscriber.report(error, handled: false, severity: :error, context: { request_id: "abc-123", http_method: "GET", path: "/catalog" }, source: "application.action_dispatch")

    assert_equal(
      { "level" => "error", "event" => "error", "handled" => false, "error_class" => "RuntimeError", "message" => "boom",
        "source" => "application.action_dispatch", "request_id" => "abc-123", "method" => "GET", "path" => "/catalog",
        "backtrace" => [ "app/models/list.rb:10:in 'x'" ] },
      line.except("time")
    )
    assert line["time"]
  end

  test "a long message is cut and a warning is logged as one" do
    @subscriber.report(RuntimeError.new("x" * 2000), handled: true, severity: :warning, context: {})

    assert_operator line["message"].length, :<=, ErrorLogSubscriber::MESSAGE_LIMIT
    assert_equal "warning", line["level"]
    assert_match(/\AWARN\|/, @io.string.lines.last)
  end

  test "it never raises" do
    Rails.logger = Object.new

    assert_nothing_raised { @subscriber.report(RuntimeError.new("x"), handled: true, severity: :error, context: {}) }
  end

  test "Rails.error.report reaches a subscriber with the request context" do
    Rails.error.subscribe(@subscriber)
    Rails.error.set_context(request_id: "req-9")
    Rails.error.report(RuntimeError.new("reported"), handled: true)

    assert_equal "req-9", line["request_id"]
    assert_equal "reported", line["message"]
  ensure
    Rails.error.unsubscribe(@subscriber)
  end
end
