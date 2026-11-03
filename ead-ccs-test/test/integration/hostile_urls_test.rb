require "test_helper"
require_relative "../support/outages"

# Addresses that people, bots and old bookmarks really produce: broken encodings, paging far past the end, a thousand-character
# search, hand-edited filters. None of them may end in a server error (500); the answer is a result, a redirect, or an error page
# in the site chrome. (Without Solr the search itself answers 503, which is also not a 500.)
class HostileUrlsTest < ActionDispatch::IntegrationTest
  include Outages

  URLS = [
    "/catalog?q=skull&page=0", "/catalog?q=skull&page=-1", "/catalog?q=skull&page=abc", "/catalog?q=skull&page=99999999999999999999",
    "/catalog?q=skull&per_page=0", "/catalog?q=skull&per_page=-5", "/catalog?q=skull&per_page=abc", "/catalog?q=skull&per_page=100000",
    "/catalog?q=skull&sort=nonsense", "/catalog?q=skull&view=bad", "/catalog?q=skull&search_field=nope",
    "/catalog?q=%00", "/catalog?q=%F0%9F%92%80", "/catalog?q=#{"a" * 5000}", "/catalog?q[]=a&q[]=b", "/catalog?q[a]=b",
    "/catalog?q=(((((((", "/catalog?q=%22unclosed", "/catalog?q=AND", "/catalog?q=-", "/catalog?q=%2B",
    "/catalog?q=skull&f[collection_ssim]=x", "/catalog?q=skull&f[collection_ssim][]=", "/catalog?q=skull&f[nope][]=x", "/catalog?q=skull&f=notahash",
    "/catalog?q=skull&f_inclusive[collection_ssim]=x",
    "/catalog?q=skull&range[date_start_isi][begin]=abc&range[date_start_isi][end]=xyz",
    "/catalog?q=skull&range[date_start_isi][begin]=2000&range[date_start_isi][end]=1000",
    "/catalog?q=skull&range[date_start_isi][begin]=99999999999999999999", "/catalog?q=skull&range=x",
    "/catalog?q=skull&clause[0][field]=nope&clause[0][query]=x", "/catalog?q=skull&clause=x", "/catalog?op=bad&clause[0][field]=all_fields&clause[0][query]=x",
    "/catalog?clause[9999][field]=title&clause[9999][query]=x", "/catalog/advanced?clause[0][query]=x", "/catalog/advanced?op=bad",
    "/catalog?q=skull&format=nope", "/catalog.json?q=skull&page=0", "/catalog.json?q=skull&per_page=abc",
    "/catalog/%00", "/catalog/#{"a" * 3000}", "/catalog/a%2Fb", "/catalog/emu-9044.nope", "/stock/does-not-exist", "/branded-stock/%00",
    "/catalog/facet/nope", "/catalog/facet/collection_ssim?facet.page=-1", "/catalog/facet/collection_ssim?facet.page=abc", "/catalog/facet/collection_ssim?facet.sort=bad",
    "/bookmarks?page=0", "/bookmarks?per_page=abc", "/bookmarks/nope", "/search_history?page=abc",
    # Malformed and oversized parameters (CCS-147)
    "/catalog?#{"a[b]" * 200}=1", "/catalog?#{(1..5000).map { |n| "p#{n}=1" }.join("&")}", "/catalog?q=skull&q[a]=b&q=c", "/catalog?%00=1",
    "/catalog?q=%FF%FE", "/catalog?f[collection_ssim][]=%E0%A4%A", "/catalog?q=skull&page=1e5", "/catalog?q=skull&page=%00",
    "/catalog?q=skull&per_page=%FF", "/catalog?range[date_start_isi][begin][]=1", "/catalog?clause[0]=x", "/catalog?sort[]=a",
    "/catalog/facet/collection_ssim?facet.prefix[]=a", "/bookmarks?page[]=1", "/search_history?page[a]=1", "/lists/%00", "/lists/abc/items",
    "/access_requests/new?document_id[]=a", "/access_requests/new?document_id=#{"a" * 5000}", "/saved_searches?page=%FF",
    "/help?topic=nope", "/help/nope", "/collections/NOPE", "/collections/%00", "/nope", "/%00", "/a/b/c/d", "/catalog/suggest?q=%00"
  ].freeze

  URLS.each do |url|
    test "#{url[0, 70]} does not end in a server error" do
      get url, headers: { "Accept" => "text/html" }

      assert_not_equal 500, response.status, "#{url} answered 500"
    end
  end

  # Posts that are not what the forms send
  test "a POST with a broken or unexpected body is answered, never with a 500" do
    as_production { posts_with_broken_bodies }
  end

  def posts_with_broken_bodies
    post "/lists", params: "list[name]=%E0%A4%A", headers: { "Content-Type" => "application/x-www-form-urlencoded" }
    assert_response :bad_request

    post "/lists", params: "{not json", headers: { "Content-Type" => "application/json" }
    assert_includes 400..499, response.status

    post "/access_requests", params: { document_id: "emu-1", access_request: "a string, not fields" }
    assert_includes [ 400, 404, 503 ], response.status # 503 where there is no Solr to look the record up

    post "/saved_searches", params: { search_id: [ 1, 2 ], name: { a: 1 } }
    assert_includes [ 200, 302, 303, 400, 404, 422, 503 ], response.status

    post "/downloads/review", params: { ids: "not-an-array" }
    assert_includes [ 200, 302, 303, 400, 404, 422, 503 ], response.status
  end
  private :posts_with_broken_bodies

  test "a request body over the limit is refused with 413 before it is read" do
    post "/lists", params: { list: { name: "a" * 2_000_000 } }

    assert_response :content_too_large
  end

  test "a query string over the limit is refused with 414" do
    get "/catalog?q=#{"a" * 9000}"

    assert_response 414
  end

  test "the limits can be changed by environment variable" do
    ENV["QUERY_STRING_MAX_BYTES"] = "100"
    get "/catalog?q=#{"a" * 200}"
    assert_response 414
  ensure
    ENV.delete("QUERY_STRING_MAX_BYTES")
  end
end
