# frozen_string_literal: true

# Refuses a request that is far larger than anything the site accepts, before it is read or parsed (CCS-144). The site's forms are
# a few kilobytes (the largest are the bulk download's record ids and an access request's purpose) and there are no uploads.
#   413 when the body is over REQUEST_MAX_BYTES (default 1 MB: 1048576)
#   414 when the query string is over QUERY_STRING_MAX_BYTES (default 8192; Puma itself stops at 12 KB for the whole request line)
# Rack's own limits then apply to what is parsed: 4096 parameters, nesting 100 deep (a deeper one is a 400).
class RequestLimits
  def initialize(app)
    @app = app
  end

  def call(env)
    return refuse(413, "Request too large.") if env["CONTENT_LENGTH"].to_i > limit("REQUEST_MAX_BYTES", 1_048_576)
    return refuse(414, "Address too long.") if env["QUERY_STRING"].to_s.bytesize > limit("QUERY_STRING_MAX_BYTES", 8192)

    @app.call(env)
  end

  private

  def limit(name, default) = Integer(ENV.fetch(name, default), exception: false) || default

  def refuse(status, text)
    [ status, { "content-type" => "text/plain; charset=utf-8", "cache-control" => "no-store", "x-robots-tag" => "noindex", "connection" => "close" }, [ "#{text}\n" ] ]
  end
end
