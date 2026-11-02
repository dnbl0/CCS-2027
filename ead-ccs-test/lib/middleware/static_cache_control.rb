# frozen_string_literal: true

# How long a browser or shared cache may keep each kind of static file (CCS-71). config.public_file_server.headers gives every file in
# public/ one lifetime; the files differ:
#   /assets/...          fingerprinted by Propshaft, so the address changes when the file does: a year, immutable
#   /digital-assets/...  the records' images, named after the record and not fingerprinted: a day, then revalidated
#   anything else        icons and the static error pages: an hour
# Only responses ActionDispatch::Static has marked public are touched; pages and anything personal are never given these headers.
class StaticCacheControl
  RULES = [
    [ %r{\A/assets/}, "public, max-age=31536000, immutable" ],
    [ %r{\A/digital-assets/}, "public, max-age=86400" ]
  ].freeze
  DEFAULT = "public, max-age=3600"

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    if [ 200, 304 ].include?(status) && headers["cache-control"].to_s.start_with?("public")
      headers["cache-control"] = RULES.find { |pattern, _| env["PATH_INFO"].match?(pattern) }&.last || DEFAULT
    end
    [ status, headers, body ]
  end
end
