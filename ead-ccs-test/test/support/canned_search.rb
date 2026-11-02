# Lets a test run the results page without a Solr core: Blacklight's repository answers every search with the response given,
# as Solr would have sent it (a Hash). For the CI job that has no Solr; tests of the real thing use needs_solr instead.
# The original is put back whatever happens, including when the test is skipped before the block runs.
module CannedSearch
  # Docs in the shape Solr sends; highlighting maps a record's id to { field => [ snippets ] }
  def canned_response(docs, highlighting: nil, total: docs.size)
    response = { "responseHeader" => { "status" => 0, "params" => {} },
                 "response" => { "numFound" => total, "start" => 0, "docs" => docs },
                 "facet_counts" => { "facet_queries" => {}, "facet_fields" => {}, "facet_ranges" => {} } }
    response["highlighting"] = highlighting if highlighting
    response
  end

  # Runs the block with searches answered by `answer`: a Hash, or a lambda taking the request's params and giving one
  def with_canned_search(answer)
    original = Blacklight::Solr::Repository.instance_method(:search)
    seen = []
    Blacklight::Solr::Repository.send(:define_method, :search) do |params: {}, **|
      seen << params
      body = answer.respond_to?(:call) ? answer.call(params) : answer
      Blacklight::Solr::Response.new(body, params.to_h, document_model: SolrDocument, blacklight_config: blacklight_config)
    end
    yield seen
  ensure
    Blacklight::Solr::Repository.send(:define_method, :search, original) if original
  end

  # The header menu's collection counts are cached for a day in production; without a cache every page would ask Solr
  def with_seeded_menu_cache
    previous = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.write(BrowseMenu::CACHE_KEY, { BrowseMenu::WITH_IMAGES => 1 }, expires_in: 1.day)
    yield
  ensure
    Rails.cache = previous if previous
  end
end
