# frozen_string_literal: true

require "test_helper"

# Dean's standing rule (25 Nov 2026): the site shows no counts of records outside the search results page (whose total and filter counts
# stay). Every Browse page, its views and the home page are read for "N records" (or items, places, collections) in what a visitor sees.
# The lists are given through the cache, as BrowsePagesTest does; a page that Solr cannot answer here says so, with no count either.
class NoCountsTest < ActionDispatch::IntegrationTest
  COUNT = /\b\d[\d,]*\s+(records?|items?|places|collections|categories|results)\b|\(\d[\d,]*\)/

  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.write(SuppressedRecord.cache_key("browse_hubs/v1/object-types"), [ [ "Lyre", 120 ], [ "Harp", 40 ] ], expires_in: 1.day)
    Rails.cache.write(SuppressedRecord.cache_key("browse_cards/v3/object-types/wall/v2"),
                      [ { "label" => "Lyre", "count" => 100, "total" => 120, "image" => { "id" => "r1", "title" => "A lyre", "path" => "https://unimelbourne.widen.net/content/x/jpeg/a.jpeg", "width" => nil, "height" => nil } } ],
                      expires_in: 1.day)
  end

  teardown { Rails.cache = @cache }

  def seen_text = Nokogiri::HTML(response.body).css("main").map(&:text).join(" ").squish

  [ "/browse/object-types", "/browse/object-types?view=az", "/browse/object-types?filter=ly" ].each do |path|
    test "#{path} shows no count" do
      get path
      assert_response :success
      assert_no_match COUNT, seen_text
    end
  end
end
