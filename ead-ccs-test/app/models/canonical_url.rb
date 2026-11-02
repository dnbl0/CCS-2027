# frozen_string_literal: true

# The canonical address of a page (CCS-128): the one address search engines are told to keep, however a visitor arrived. A results
# page keeps what changes its results (search words, filters, range, advanced clauses, the page after the first) and drops what only
# changes how they are shown or who sent the visitor (sort, view, per_page, utm_*, anything unknown). A record page is /catalog/:id
# whichever of the three record pages it is.
module CanonicalUrl
  RESULTS_PARAMS = %w[q search_field f range op clause any_assets].freeze

  # path: the request path; params: its query parameters. Returns an absolute URL.
  def self.for(base_url, path, params = {})
    base = base_url.to_s.chomp("/")
    path = path.to_s.sub(%r{\A/(?:stock|branded-stock)/}, "/catalog/").sub(%r{(\A/catalog/[^/]+)/citation\z}, '\1')
    path = "/" if path.blank?
    return "#{base}#{path == '/' ? '/' : path}" unless path == "/catalog"

    kept = params.to_h.stringify_keys.slice(*RESULTS_PARAMS).compact_blank
    kept["page"] = params.to_h.stringify_keys["page"] if params.to_h.stringify_keys["page"].to_i > 1
    kept.empty? ? "#{base}#{path}" : "#{base}#{path}?#{kept.to_query}"
  end
end
