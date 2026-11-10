# frozen_string_literal: true

# How long a browser or shared cache may keep each kind of static file (CCS-71). config.public_file_server.headers gives every file in
# public/ one lifetime; the files differ:
#   /assets/...          fingerprinted by Propshaft, so the address changes when the file does: a year, immutable
#   /digital-assets/...  the records' media, named after the file and not fingerprinted, so a file can be replaced under the same
#                        name (CCS-425). With the version token the pages add (AssetVersion: ?v=...) the address changes when the
#                        file does: a year, immutable. Without one (an old link, another site's embed) the browser may keep the
#                        file but must ask the server before using it again; the server answers 304 while it is unchanged.
#   anything else        icons and the static error pages: an hour
# Only responses ActionDispatch::Static has marked public are touched; pages and anything personal are never given these headers.
class StaticCacheControl
  IMMUTABLE = "public, max-age=31536000, immutable"
  REVALIDATE = "public, max-age=0, must-revalidate"
  RULES = [
    [ %r{\A/assets/}, IMMUTABLE ],
    [ %r{\A/digital-assets/}, ->(env) { AssetVersion.versioned?(env["QUERY_STRING"]) ? IMMUTABLE : REVALIDATE } ]
  ].freeze
  DEFAULT = "public, max-age=3600"

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    if [ 200, 304 ].include?(status) && headers["cache-control"].to_s.start_with?("public")
      rule = RULES.find { |pattern, _| env["PATH_INFO"].match?(pattern) }&.last
      headers["cache-control"] = rule.respond_to?(:call) ? rule.call(env) : (rule || DEFAULT)
    end
    [ status, headers, body ]
  end
end
