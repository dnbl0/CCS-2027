# Be sure to restart your server when you modify this file.

# Content Security Policy, in REPORT-ONLY mode: browsers log what the policy would block (see the console) but block
# nothing. Blacklight and the importmap use inline scripts and styles, so enforcing it needs a pass over every page for
# violations first. When the console is quiet on all pages, set report_only to false (and add a report_uri to collect them).
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data, :https
    policy.object_src  :none
    policy.base_uri    :self
    policy.frame_ancestors :self
    policy.form_action :self, "https://search.unimelb.edu.au"
    policy.script_src  :self
    policy.style_src   :self, :unsafe_inline # Blacklight sets some inline styles
    policy.connect_src :self
    # Audio and video play from this site, from the Nexus DAM's embed links (digital_media_ssim, written by the DAM sync) and from
    # CCS_MEDIA_BASE_URL when that is on another host. Images already come from any https host (img-src), DAM images included.
    media_base = ENV["CCS_MEDIA_BASE_URL"].to_s[%r{\Ahttps://[^/]+}]
    policy.media_src :self, "https://unimelbourne.widen.net", *media_base
  end

  # Nonces for the importmap and inline scripts
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  config.content_security_policy_report_only = true
end
