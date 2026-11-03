require "test_helper"
require_relative "../support/env_override"
require_relative "../support/request_counter"
require_relative "../support/canned_search"

# The rate limit and the work budget of the shared pages: galleries, embeds and oEmbed count as record requests, and a
# gallery makes one batched Solr request however many records it holds.
class SharingLimitsTest < ActionDispatch::IntegrationTest
  include EnvOverride
  include RequestCounter
  include CannedSearch

  BROWSER = { "User-Agent" => "Mozilla/5.0 (X11; Linux x86_64) Firefox/126.0" }.freeze
  IDS = %w[emu-400198 emu-400205 emu-400001].freeze

  setup { BotGuard.store.clear }

  test "a gallery, an embed and oEmbed share the record request limit, so a token cannot be guessed at speed" do
    token = "a" * 32
    with_env("RATE_LIMIT" => "on", "RATE_LIMIT_RECORD_PER_MINUTE" => "3") do
      3.times { get "/galleries/#{token}", headers: BROWSER }
      assert_response :not_found
      get "/galleries/#{token}", headers: BROWSER
      assert_response :too_many_requests

      get "/embed/galleries/#{token}", headers: BROWSER
      assert_response :too_many_requests
      get "/oembed", params: { url: "http://www.example.com/galleries/#{token}" }, headers: BROWSER
      assert_response :too_many_requests
    end
  end

  def shared_list(ids)
    list = User.create!.lists.create!(name: "Strings")
    ids.each { |id| list.list_items.create!(document_id: id) }
    list.share!
  end

  test "a gallery page asks Solr once, for all its records, and makes the same few queries for a short or a long list" do
    needs_solr
    short = shared_list(IDS.first(1))
    long = shared_list(IDS + (1..40).map { |n| "emu-4003#{n}" })
    with_seeded_menu_cache do
      get "/galleries/#{short.share_token}" # the first request of a process warms its caches
      one = count_requests { get "/galleries/#{short.share_token}" }
      many = count_requests { get "/galleries/#{long.share_token}" }

      assert_equal 1, one.solr, one.solr_requests.join("\n")
      assert_equal 1, many.solr, many.solr_requests.join("\n")
      assert_operator many.sql, :<=, 3, many.statements.join("\n")
      assert_operator many.sql, :<=, one.sql, "the number of queries grows with the number of records (N+1)"
    end
  end

  test "an embed asks Solr once, and oEmbed of a gallery asks it never" do
    needs_solr
    list = shared_list(IDS)
    record = count_requests { get "/embed/records/emu-400198" }
    gallery = count_requests { get "/embed/galleries/#{list.share_token}" }
    oembed = count_requests { get "/oembed", params: { url: "http://www.example.com/galleries/#{list.share_token}" } }

    assert_equal 1, record.solr, record.solr_requests.join("\n")
    assert_equal 1, gallery.solr, gallery.solr_requests.join("\n")
    assert_equal 0, oembed.solr
    assert_equal 0, record.sql, "a record embed needs no database"
  end

  test "a gallery page is not publicly cacheable: a revoked link must stop working at once" do
    needs_solr
    list = shared_list(IDS.first(1))
    get "/galleries/#{list.share_token}"

    assert_no_match(/public/, response.headers["Cache-Control"].to_s)
    get "/embed/galleries/#{list.share_token}"
    assert_no_match(/public/, response.headers["Cache-Control"].to_s)
  end
end
