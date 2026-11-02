# Response headers beyond Rails' defaults (CCS-148). What is already sent, by Rails: X-Frame-Options SAMEORIGIN, X-Content-Type-Options
# nosniff, Referrer-Policy strict-origin-when-cross-origin, X-Permitted-Cross-Domain-Policies none. The Content-Security-Policy is
# config/initializers/content_security_policy.rb. Strict-Transport-Security comes from config.force_ssl (production.rb, RAILS_FORCE_SSL):
# the Azure deployment scripts set RAILS_FORCE_SSL=true, so deployed copies send it. It is not forced here: HSTS sent before HTTPS works on a host name locks visitors out.

# Cross-Origin-Opener-Policy: a page opened from here cannot reach this window through window.opener, and the reverse. The site
# opens no pop-up windows that need the opener, so this is safe.
Rails.application.config.action_dispatch.default_headers["Cross-Origin-Opener-Policy"] = "same-origin"

# Permissions-Policy: the browser features the site does not use are switched off, so a script that ever got onto a page could not
# use them. Full screen stays for the site itself (the record viewer's full-screen button), and so does copying (the Copy buttons).
# Written as the header itself: Rails' config.permissions_policy sends the older Feature-Policy header, which browsers have dropped.
switched_off = %w[camera microphone geolocation payment usb serial hid midi accelerometer gyroscope magnetometer display-capture]
Rails.application.config.action_dispatch.default_headers["Permissions-Policy"] =
  (switched_off.map { |feature| "#{feature}=()" } + [ "fullscreen=(self)", "clipboard-write=(self)" ]).join(", ")
