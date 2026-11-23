# frozen_string_literal: true

# Email addresses in HTML pages written as character references (CCS-233; lib/middleware/email_protection.rb). The middleware is in
# lib/middleware, which is not autoloaded (a middleware class is needed before the app has loaded).
require Rails.root.join("lib/middleware/email_protection")

Rails.application.config.middleware.use EmailProtection
