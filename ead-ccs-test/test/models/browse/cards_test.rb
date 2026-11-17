# frozen_string_literal: true

require "test_helper"
require_relative "../../support/discovery_records"
require_relative "../../support/outages"

class Browse::CardsTest < ActiveSupport::TestCase
  include DiscoveryRecords
  include Outages

  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @cache }

  def hub(slug) = BrowseHubs.find(slug)

  # What the index answers: the values that have records with a thumbnail (facet), the records of a value (for its picture) and the
  # kinds and collections of a value's records (its description)
  def index(values:, records: {}, facet_queries: {})
    lambda do |params|
      params = params.to_h.with_indifferent_access
      if params[:"facet.query"]
        canned_response([]).tap { |body| body["facet_counts"]["facet_queries"] = facet_queries }
      elsif params[:"facet.field"].is_a?(Array)
        canned_response([]).tap do |body|
          body["facet_counts"]["facet_fields"] = { "classification_ssim" => [ "prints", 3, "drawings", 1 ], "collection_ssim" => [ "University Art Collection", 4 ] }
        end
      elsif params[:"facet.field"]
        canned_response([]).tap { |body| body["facet_counts"]["facet_fields"] = { params[:"facet.field"] => values.flatten } }
      else
        label = params[:fq].to_a.last.to_s[/"(.*)"/, 1]
        canned_response(records.fetch(label, []))
      end
    end
  end

  test "a hub has eight values that have a picture, each opening the results with the value as a filter, with a description" do
    values = (1..12).map { |number| [ "Place #{number}", 100 - number ] }
    records = values.to_h { |label, _count| [ label, [ view_only_record("r-#{label}") ] ] }

    cards = with_canned_search(index(values: values, records: records)) { |_seen| Browse::Cards.for(hub("places")) }

    assert_equal (1..8).map { |number| "Place #{number}" }, cards.map(&:label)
    assert_equal({ any_assets: "1", f: { "production_place_ssim" => [ "Place 1" ] }, search_field: "all_fields" }, cards.first.query)
    assert_equal "Includes prints, drawings. Held in University Art Collection.", cards.first.intro
    assert cards.all?(&:image)
  end

  test "a value whose records show no picture is passed over for the next" do
    values = [ [ "Withheld", 50 ], [ "Seen", 40 ], [ "Sensitive", 30 ] ]
    records = { "Withheld" => [ withheld_record("w") ], "Seen" => [ view_only_record("s") ], "Sensitive" => [ sensitive_record("x") ] }

    cards = with_canned_search(index(values: values, records: records)) { |_seen| Browse::Cards.for(hub("places")) }

    assert_equal [ "Seen" ], cards.map(&:label)
  end

  test "no picture is shown twice" do
    values = [ [ "A", 50 ], [ "B", 40 ] ]
    shared = view_only_record("same")
    cards = with_canned_search(index(values: values, records: { "A" => [ shared ], "B" => [ shared ] })) { |_seen| Browse::Cards.for(hub("places")) }

    assert_equal [ "A" ], cards.map(&:label)
  end

  test "the object type cards use the Classification facet" do
    values = [ [ "paintings", 9 ] ]
    cards = with_canned_search(index(values: values, records: { "paintings" => [ open_record("p") ] })) { |_seen| Browse::Cards.for(hub("object-types")) }

    assert_equal "Paintings", cards.first.label
    assert_equal({ any_assets: "1", f: { "classification_ssim" => [ "paintings" ] }, search_field: "all_fields" }, cards.first.query)
    assert_equal "Held in University Art Collection.", cards.first.intro
  end

  test "the periods are cards in order of time that open the period's range" do
    first = ExploreEntryPoints.period_query(1950, 1959)
    last = ExploreEntryPoints.period_query(1960, 1969)
    records = { first => [ open_record("a") ], last => [ open_record("b") ] }
    answer = lambda do |params|
      params = params.to_h.with_indifferent_access
      if params[:"facet.query"]
        canned_response([]).tap { |body| body["facet_counts"]["facet_queries"] = { last => 20, first => 10 } }
      elsif params[:"facet.field"]
        index(values: [])[params]
      else
        canned_response(records.fetch(params[:fq].to_a.last, []))
      end
    end

    cards = with_canned_search(answer) { |_seen| Browse::Cards.for(hub("periods")) }

    assert_equal [ "1950–1959", "1960–1969" ], cards.map(&:label)
    assert_equal BrowseHubs.period_query(1950, 1959), cards.first.query
  end

  test "when the index cannot answer there are no cards" do
    with_solr_down { assert_empty Browse::Cards.for(hub("subjects")) }
  end
end
