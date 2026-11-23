# frozen_string_literal: true

# Site analytics (CCS-53): the University measures engagement in Adobe Customer Journey Analytics, so the site's only part is to
# load the Adobe tag (Adobe Experience Platform Tags, the "launch-....min.js" script). ADOBE_ANALYTICS_SCRIPT_URL is that script's
# https address, from the University's digital team; unset (the default) there is no analytics at all and the cookie notice says so.
# Set, analytics is an optional cookie category (CookieNotice): the tag loads only after the visitor accepts it, never before.
module Analytics
  # The hosts the Adobe tag talks to (its collection and identity services), for the Content-Security-Policy's connect-src
  CONNECT_HOSTS = %w[https://*.adobedc.net https://*.omtrdc.net https://*.demdex.net https://assets.adobedtm.com].freeze
  # The cookies Adobe's tag and identity service set (for the notice and the privacy page)
  COOKIES = %w[AMCV_* AMCVS_* kndctr_* s_cc s_sq].freeze

  module_function

  def script_url
    url = ENV["ADOBE_ANALYTICS_SCRIPT_URL"].to_s.strip
    url if url.match?(%r{\Ahttps://[^\s/]+/\S+\.js\z})
  end

  def enabled? = script_url.present?

  # The tag's own host, for script-src
  def script_origin = script_url.to_s[%r{\Ahttps://[^/]+}]
end
