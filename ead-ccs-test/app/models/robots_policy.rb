# frozen_string_literal: true

# Which pages search engines may index (CCS-128) and what AI crawlers may do with them (CCS-127), in one place. The answer is a
# robots directive, sent as the X-Robots-Tag header (BotGuard, for every response) and repeated in a <meta name="robots"> tag
# (layouts/_seo_head), so the two cannot disagree.
#
#   indexed                 home, Help, About, Advanced search, the results of the whole site or of one collection (page 1, no
#                           search words or other filter), and a record page whose asset may be shown and is not sensitive
#   noindex, follow         other results pages (a search, a filter, page 2 on: endless near-duplicates of the pages above, but
#                           the records they link to are worth following), and the record pages withheld below
#   noindex, nofollow       personal or action pages (history, saved items, lists, access requests, downloads, exports, the
#                           sensitivity choice, citations, the comparison page, IIIF manifests), the facet and range endpoints, the stock comparison record pages
#                           (a copy of /catalog/:id), the error pages
#   noindex                 the asset files under /digital-assets
#
# A record page is not indexed when its asset is withheld (AccessPolicy :request) or sensitive (Sensitivity): Indigenous cultural
# material is handled conservatively, so its title and description stay out of search results. The page works as ever for a visitor.
# Every page also says noai, noimageai (honoured by some AI crawlers, ignored by others).
module RobotsPolicy
  AI = "noai, noimageai"
  NOINDEX_FOLLOW = "noindex, follow"
  NOINDEX_NOFOLLOW = "noindex, nofollow"

  # Paths of personal or action pages; also the Disallow lines of robots.txt (RobotsTxt), prefix match
  PERSONAL_PREFIXES = %w[/bookmarks /saved_searches /search_history /lists /compare /access_requests /downloads /errors /400 /404 /406 /422 /500].freeze
  # /catalog/:id/<this>
  PERSONAL_RECORD_ACTIONS = %w[metadata sensitivity citation manifest manifest.json].freeze
  # Parts of /catalog that are not a results page or a record: the facet lists, the range chart data, suggestions, OpenSearch
  CATALOG_SUPPORT = %w[facet range_limit suggest opensearch].freeze
  # Not a page for a person to find: left alone (no header)
  UNTOUCHED_PREFIXES = %w[/assets /up /icon.png /icon.svg].freeze

  # The facet filters a results page may carry and still be indexed: the default digital-asset choice, one collection
  INDEXABLE_FILTERS = %w[has_digital_asset collection_ssim].freeze

  # path: request path; params: the query parameters. document: the record, on a record page. Returns a directive string, or
  # nil for a path no header belongs on (the site's own scripts and styles).
  def self.directive(path, params = {}, document: nil, indexing: BotControls.indexing?)
    path = path.to_s
    return nil if UNTOUCHED_PREFIXES.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") }

    ai = BotControls.enabled? ? AI : nil
    return join("noindex", ai) if path.start_with?("/digital-assets/")
    return join(NOINDEX_NOFOLLOW, ai) if !indexing || personal?(path) || stock?(path)
    return join(NOINDEX_FOLLOW, ai) if results?(path) && !indexable_results?(params)
    return join(NOINDEX_FOLLOW, ai) if document && withheld?(document)

    join(nil, ai)
  end

  # A record whose title and description stay out of search results (see above)
  def self.withheld?(document) = AccessPolicy.tier(document) == :request || Sensitivity.sensitive?(document)

  def self.personal?(path)
    PERSONAL_PREFIXES.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") || path.start_with?("#{prefix}.") } ||
      path.match?(%r{\A/catalog/(#{CATALOG_SUPPORT.join('|')})(/|\.|\z)}) ||
      path.match?(%r{\A/catalog/[^/]+/(#{PERSONAL_RECORD_ACTIONS.join('|')})\z})
  end

  def self.stock?(path) = path.start_with?("/stock/", "/branded-stock/")

  def self.results?(path) = path == "/catalog" || path == "/catalog.json"

  # Page 1 of the results of the whole site or of one collection, nothing else asked
  def self.indexable_results?(params)
    params = params.to_h.with_indifferent_access
    return false if params[:q].present? || params[:clause].present? || params[:range].present?
    return false if params[:page].to_i > 1

    filters = params[:f].respond_to?(:to_h) ? params[:f].to_h : {}
    filters.keys.all? { |name| INDEXABLE_FILTERS.include?(name) } &&
      Array(filters["has_digital_asset"]).all?("with") && Array(filters["collection_ssim"]).size <= 1
  end

  def self.join(*parts) = parts.compact.join(", ")
  private_class_method :join
end
