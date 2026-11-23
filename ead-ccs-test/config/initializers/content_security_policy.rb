# Be sure to restart your server when you modify this file.

# Content Security Policy, in REPORT-ONLY mode: browsers log what the policy would block (see the console) but block
# nothing. Blacklight and the importmap use inline scripts and styles, so enforcing it needs a pass over every page for
# violations first. When the console is quiet on all pages, set report_only to false (and add a report_uri to collect them).
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    # blob: for an eBook's own fonts, pictures and styles, which epub.js hands its page as blob: addresses (CCS-164)
    policy.font_src    :self, :data, :blob
    # The Explore by place map's tiles (Explore::MapTiles), named even though https: covers them, so the policy stays right when
    # https: is narrowed. The browser asks this host only once the visitor presses "Show the map".
    policy.img_src     :self, :data, :blob, :https, -> { Explore::MapTiles.origin } # a lambda: worked out per request, once the app has loaded
    policy.object_src  :none
    policy.base_uri    :self
    policy.frame_ancestors :self
    policy.form_action :self, "https://search.unimelb.edu.au"
    # 'wasm-unsafe-eval': the 3D viewer's draco and KTX2 decoders are WebAssembly (CCS-164); it allows compiling WebAssembly, not eval
    policy.script_src  :self, :wasm_unsafe_eval, -> { Analytics.enabled? ? [ Analytics.script_origin ] : [] } # the Adobe tag's host once analytics is on (CCS-53)
    policy.style_src   :self, :unsafe_inline, :blob # Blacklight sets some inline styles; an eBook's styles are blob: (CCS-164)
    # Audio and video play from this site, from the Nexus DAM's embed links (digital_media_ssim, written by the DAM sync) and from
    # CCS_MEDIA_BASE_URL when that is on another host. Images already come from any https host (img-src), DAM images included.
    # eBooks and 3D models (CCS-164) are fetched by script from the same places, so connect-src names them too.
    media_base = ENV["CCS_MEDIA_BASE_URL"].to_s[%r{\Ahttps://[^/]+}]
    media_hosts = [ "https://unimelbourne.widen.net", *media_base ]
    policy.connect_src :self, *media_hosts, -> { Analytics.enabled? ? Analytics::CONNECT_HOSTS : [] } # the Adobe tag's services once analytics is on (CCS-53)
    policy.media_src :self, *media_hosts
    policy.worker_src :self, :blob # the 3D viewer decodes compressed models in workers it starts from blob: addresses (CCS-164)
  end

  # Nonces for the importmap and inline scripts
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  config.content_security_policy_report_only = true
end
