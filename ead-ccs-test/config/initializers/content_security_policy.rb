# Be sure to restart your server when you modify this file.

# Content Security Policy, in REPORT-ONLY mode: browsers log what the policy would block (see the console) but block
# nothing. Blacklight and the importmap use inline scripts and styles, so enforcing it needs a pass over every page for
# violations first. When the console is quiet on all pages, set report_only to false (and add a report_uri to collect them).
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    # The Explore by place map's tiles (Explore::MapTiles), named even though https: covers them, so the policy stays right when
    # https: is narrowed. The browser asks this host only once the visitor presses "Show the map".
    policy.img_src     :self, :data, :https, -> { Explore::MapTiles.origin } # a lambda: worked out per request, once the app has loaded
    policy.object_src  :none
    policy.base_uri    :self
    policy.frame_ancestors :self
    policy.form_action :self, "https://search.unimelb.edu.au"
    policy.script_src  :self
    policy.style_src   :self, :unsafe_inline # Blacklight sets some inline styles
    policy.connect_src :self
  end

  # Nonces for the importmap and inline scripts
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  config.content_security_policy_report_only = true
end
