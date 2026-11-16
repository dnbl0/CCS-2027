# frozen_string_literal: true

# The one place a suppressed record (SuppressedRecord, CCS-112) is kept out of what Solr answers. Prepended to RSolr::Client
# (config/initializers/suppressed_records.rb), so it covers Blacklight's repository (search results, facets, a record page, the
# facet "more" lists), Discovery.search, Browse::Profile, RecordSummaries, SimilarRecords, RelatedObjects, the sitemap, the browse
# counts and anything written later that asks Solr through the client. It adds one filter query; the request is otherwise
# unchanged. Handlers that are not searches (admin, update, the suggester) are left alone.
module SuppressedSolrFilter
  NOT_A_SEARCH = %r{\A/?(admin|update|suggest|schema|config)(/|\z)}
  # A GET with a long filter would pass Solr's header limit: send it as a POST (the form body has no such limit)
  LONG = 1500

  def send_and_receive(path, opts = {})
    filter = SuppressedRecord.solr_filter unless NOT_A_SEARCH.match?(path.to_s)
    filter ? super(path, SuppressedSolrFilter.apply(opts, filter)) : super
  end

  # `opts` with the filter added to its fq (in :data when that is a form hash, else in :params), as a new hash
  def self.apply(opts, filter)
    opts = (opts || {}).dup
    key = opts[:data].is_a?(Hash) ? :data : :params
    params = (opts[key] || {}).to_h
    name = params.key?(:fq) ? :fq : "fq"
    params = params.merge(name => Array(params[name]) + [ filter ])
    opts[key] = params
    opts[:method] = :post if filter.bytesize > LONG && key == :params && opts[:data].blank? && opts[:method].to_s != "post"
    opts
  end
end
