# Bot controls and the rate limit (CCS-127): ahead of the static file server, so the asset files are covered too.
# The middleware is in lib/middleware, which is not autoloaded (a middleware class is needed before the app has loaded).
require Rails.root.join("lib/middleware/bot_guard")

Rails.application.config.middleware.insert_before ActionDispatch::Static, BotGuard
