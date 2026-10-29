require "test_helper"

class BrowseMenuTest < ActiveSupport::TestCase
  COUNTS = { [ "collection_ssim", "Grainger Museum Collection" ] => 13_408 }.freeze

  test "one group: the collections in menu order" do
    groups = BrowseMenu.groups(COUNTS)

    assert_equal [ "Museums and collections" ], groups.map(&:heading)
    assert_equal SitePages.menu.map(&:first), groups.first.items.map(&:label)
  end

  test "each link knows its record count, and an unknown count is nil" do
    collections, = BrowseMenu.groups(COUNTS)

    assert_equal 13_408, collections.items.find { |item| item.value == "Grainger Museum Collection" }.count
    assert_nil collections.items.find { |item| item.value == "Medical History Museum" }.count
  end

  test "every link opens all of its records, keeping the default Digital asset filter off" do
    assert_equal({ any_assets: "1", f: { "classification_ssim" => [ "Archive" ] }, search_field: "all_fields" }, BrowseMenu.query("classification_ssim", "Archive"))
    assert_nil SearchDefaults.decide(BrowseMenu.query("classification_ssim", "Archive").deep_stringify_keys, html: true, get: true, catalog: true)
  end

  # Stands in for the Solr connection: records the request and gives back a canned response, or raises
  class FakeConnection
    attr_reader :requests

    def initialize(response: nil, error: nil) = (@response, @error, @requests = response, error, [])

    def get(path, params:)
      @requests << [ path, params ]
      raise @error if @error

      @response
    end
  end

  test "the counts come from one Solr request, one facet query per link" do
    connection = FakeConnection.new(response: { "response" => { "numFound" => 40_962 }, "facet_counts" => { "facet_queries" => { %(collection_ssim:"Grainger Museum Collection") => 13_408 } } })

    counts = BrowseMenu.counts(connection)

    assert_equal 13_408, counts[[ "collection_ssim", "Grainger Museum Collection" ]]
    assert_equal 1, connection.requests.size
    path, params = connection.requests.first
    assert_equal "select", path
    assert_equal 0, params[:rows]
    assert_includes params[:"facet.query"], %(collection_ssim:"Medical History Museum")
    assert_includes params[:"facet.query"], %(has_digital_asset_bsi:"true")
  end

  test "when Solr cannot answer, the menu has no counts instead of failing" do
    assert_equal({}, BrowseMenu.counts(FakeConnection.new(error: Faraday::ConnectionFailed.new("Connection refused"))))
    assert BrowseMenu.groups({}).flat_map(&:items).all? { |item| item.count.nil? }
  end
end
