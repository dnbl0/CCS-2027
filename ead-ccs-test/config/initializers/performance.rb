# Response compression and static file lifetimes (CCS-71). The container runs Puma directly (the Dockerfile's CMD is rails server;
# Thruster, which would compress and cache, is in the Gemfile but is not started), so nothing in front of the app compresses.
# A host that does (a CDN, Thruster, nginx) sees a response already carrying Content-Encoding and leaves it alone.
require Rails.root.join("lib/middleware/static_cache_control")

# Text only: images, fonts and zips are already compressed. Small bodies cost more to compress than they save.
# (BREACH: Rails masks the CSRF token differently on every response, so compressing HTML that carries it does not leak it.)
COMPRESSIBLE = %w[text/html text/css text/plain text/csv text/xml application/xml application/json application/javascript text/javascript image/svg+xml].freeze
Rails.application.config.middleware.insert_before ActionDispatch::Static, Rack::Deflater,
  include: COMPRESSIBLE,
  if: ->(_env, _status, headers, _body) { headers["content-length"].nil? || headers["content-length"].to_i >= 1024 }

# Fingerprinted assets are immutable and the records' images last a day (production.rb sets the hour for everything else)
Rails.application.config.middleware.insert_before ActionDispatch::Static, StaticCacheControl
