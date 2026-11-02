# frozen_string_literal: true

# The settings of the SEO and bot controls (CCS-127, CCS-128) and the lists of user agents they act on. Every setting is an
# environment variable with a default; docs/seo-and-bot-controls.md lists them. Read on each call, so a test (or a restart with
# a new value) changes them without more.
module BotControls
  AGENTS = YAML.load_file(Rails.root.join("config/ai_crawlers.yml")).transform_values { |names| names.freeze }.freeze

  # Switched on by the word "on" (anything else is off); an unset setting takes the default
  def self.on?(name, default)
    ENV.fetch(name, default ? "on" : "off").to_s.strip.casecmp?("on")
  end

  # Search engines may index the site. Off outside production, so a test or staging copy is never indexed by accident; the
  # live site turns on by default (set SEO_INDEXING=off to withdraw it from search engines).
  def self.indexing? = on?("SEO_INDEXING", Rails.env.production?)

  # The AI-crawler rules (robots.txt, 403s, noai tags). The rate limit has its own switch.
  def self.enabled? = on?("BOT_CONTROLS", true)

  # /llms.txt: off until the wording has been approved
  def self.llms_txt? = on?("SEO_LLMS_TXT", false)

  def self.block_ai_retrieval? = on?("BOT_BLOCK_AI_RETRIEVAL", false)

  # The user-agent tokens named in robots.txt
  def self.disallowed_crawlers
    block_ai_retrieval? ? AGENTS.fetch("training_and_scraping") + AGENTS.fetch("ai_retrieval") : AGENTS.fetch("training_and_scraping")
  end

  # The user agents that get a 403 on the asset files and the zip/CSV endpoints: the crawlers above, the scrapers, and BOT_BLOCKED_USER_AGENTS
  def self.blocked_user_agents
    disallowed_crawlers + AGENTS.fetch("scrapers") + list("BOT_BLOCKED_USER_AGENTS")
  end

  def self.blocked_user_agent?(user_agent)
    agent = user_agent.to_s.downcase
    agent.present? && blocked_user_agents.any? { |token| agent.include?(token.downcase) }
  end

  # The site's address in canonical links, the sitemap and the structured data. SEO_CANONICAL_BASE_URL fixes it (a proxy may
  # present the app under another host); otherwise it is the address the request came to.
  def self.base_url(request)
    ENV["SEO_CANONICAL_BASE_URL"].presence&.chomp("/") || request.base_url
  end

  def self.sitemap_cache_hours = Integer(ENV.fetch("SEO_SITEMAP_CACHE_HOURS", 12), exception: false) || 12

  def self.list(name) = ENV.fetch(name, "").split(",").map(&:strip).compact_blank
end
