# frozen_string_literal: true

# The text of /robots.txt (CCS-128, CCS-127). robots.txt is advisory: well-behaved crawlers follow it, others do not (BotGuard and
# the CDN/WAF are for those). Googlebot, Bingbot and other crawlers not named below follow the "*" group.
module RobotsTxt
  # Paths no crawler should fetch: personal or action pages, endpoints that are not pages, copies of the record page, the asset files
  DISALLOWED = (RobotsPolicy::PERSONAL_PREFIXES.map { |prefix| "#{prefix}/" } + %w[
    /bookmarks /selection /saved_searches /search_history /lists /access_requests /downloads
    /catalog/facet/ /catalog/range_limit /catalog/suggest /catalog/opensearch
    /catalog/*/metadata /catalog/*/sensitivity /catalog/*/citation
    /stock/ /branded-stock/ /digital-assets/
  ]).uniq.freeze

  def self.to_s(base_url)
    return "# Search engines are not invited to this copy of the site.\nUser-agent: *\nDisallow: /\n" unless BotControls.indexing?

    lines = [ "# Collections Navigator, University of Melbourne. See /llms.txt for how the site's content may be used." ]
    if BotControls.enabled?
      lines << "# AI training crawlers and bulk scrapers are not welcome (list: config/ai_crawlers.yml)."
      lines += BotControls.disallowed_crawlers.map { |agent| "User-agent: #{agent}" }
      lines << "Disallow: /" << ""
    end
    lines << "User-agent: *"
    lines += DISALLOWED.map { |path| "Disallow: #{path}" }
    lines << "" << "Sitemap: #{base_url}/sitemap.xml"
    lines.join("\n") + "\n"
  end
end
