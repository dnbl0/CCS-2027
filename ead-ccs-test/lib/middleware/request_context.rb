# frozen_string_literal: true

# Puts the request id, method and path (never the query string: searches can hold personal words) in the error reporter's context
# for the length of the request, so every report (ErrorLogSubscriber) says which request it belongs to. After ActionDispatch::RequestId.
class RequestContext
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    Rails.error.set_context(request_id: env["action_dispatch.request_id"], http_method: request.request_method, path: request.path)
    @app.call(env)
  end
end
