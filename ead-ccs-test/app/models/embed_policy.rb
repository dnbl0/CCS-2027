# frozen_string_literal: true

# Which sites may frame the embed pages (/embed/*), and the headers that say so. Every other page of the site stays unframable
# (X-Frame-Options SAMEORIGIN, frame-ancestors 'self'); an embed page drops X-Frame-Options and sends its own, enforced
# Content-Security-Policy: frame-ancestors and nothing it loads beyond the site's own images and styles.
#
# EMBED_FRAME_ANCESTORS (docs/configuration.md): unset or "*" lets any site frame an embed, which is the default because the
# embeds show only what any visitor may see; otherwise a space or comma separated list of origins (https://example.org,
# https://*.example.edu). Anything that is not a plain origin is ignored, so a typo cannot widen the policy.
module EmbedPolicy
  ORIGIN = %r{\Ahttps?://(\*\.)?[a-z0-9]([a-z0-9.-]*[a-z0-9])?(:\d{1,5})?\z}i

  # The frame-ancestors sources, always including 'self'
  def self.ancestors(setting = ENV["EMBED_FRAME_ANCESTORS"])
    entries = setting.to_s.split(/[\s,]+/).compact_blank
    return [ "*" ] if entries.empty? || entries.include?("*")

    [ "'self'" ] + entries.grep(ORIGIN).uniq
  end

  # The enforced policy of an embed page
  def self.content_security_policy(setting = ENV["EMBED_FRAME_ANCESTORS"])
    [ "default-src 'none'", "img-src 'self' data:", "style-src 'self'", "font-src 'self'", "base-uri 'none'", "form-action 'none'",
      "frame-ancestors #{ancestors(setting).join(' ')}" ].join("; ")
  end
end
