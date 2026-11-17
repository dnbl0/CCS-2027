# frozen_string_literal: true

require "test_helper"

class Browse::CardsTest < ActiveSupport::TestCase
  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @cache }

  Doc = Struct.new(:id, :fields) do
    def [](key) = fields[key]
  end

  def hub(slug) = BrowseHubs.find(slug)

  test "a hub has the eight values with the most records, with the search that applies the value as a filter" do
    Rails.cache.write("browse_hubs/v1/places", (1..12).map { |number| [ "Place #{number}", 100 - number ] }, expires_in: 1.day)

    cards = Browse::Cards.for(hub("places"))

    assert_equal (1..8).map { |number| "Place #{number}" }, cards.map(&:label)
    assert_equal({ any_assets: "1", f: { "production_place_ssim" => [ "Place 1" ] }, search_field: "all_fields" }, cards.first.query)
    assert_equal "99 records of this place", cards.first.intro
  end

  test "the intro is singular for one record and has a thousands separator" do
    Rails.cache.write("browse_hubs/v1/makers", [ [ "A", 12_345 ], [ "B", 1 ] ], expires_in: 1.day)

    assert_equal [ "12,345 records of this maker", "1 record of this maker" ], Browse::Cards.for(hub("makers")).map(&:intro)
  end

  test "the periods are cards that open the period's range" do
    Rails.cache.write("browse_hubs/v1/periods", [ [ "1950–1959", 12, 1950, 1959 ] ], expires_in: 1.day)

    card = Browse::Cards.for(hub("periods")).first

    assert_equal BrowseHubs.period_query(1950, 1959), card.query
  end

  test "a value with no usable list has no cards" do
    assert_empty Browse::Cards.for(hub("subjects"))
  end

  # Replaces module methods for the block (minitest 6 has no stub): { object => { name => lambda } }
  def replacing(replacements)
    saved = replacements.flat_map { |object, methods| methods.keys.map { |name| [ object, name, object.method(name) ] } }
    replacements.each { |object, methods| methods.each { |name, body| object.define_singleton_method(name, &body) } }
    yield
  ensure
    saved.each { |object, name, original| object.define_singleton_method(name, original) }
  end

  test "a picture is only drawn from a record whose asset may be seen and that is not sensitive" do
    seen = Doc.new("a", "thumbnail_path_ssi" => "/digital-assets/thumbs/a.jpg", "title_tsim" => [ "Seen" ])
    withheld = Doc.new("b", "thumbnail_path_ssi" => "/digital-assets/thumbs/b.jpg")
    response = Struct.new(:documents).new([ withheld, seen ])
    candidate = { "label" => "Work", "count" => 5 }
    search = ->(*) { response }

    image = replacing(Discovery => { search: search }, AccessPolicy => { view?: ->(document) { document.id != "b" } }, Sensitivity => { sensitive?: ->(_document) { false } }) do
      Browse::Cards.send(:example_image, hub("object-types"), candidate, [])
    end

    assert_equal "a", image[:id]

    sensitive = replacing(Discovery => { search: search }, AccessPolicy => { view?: ->(_document) { true } }, Sensitivity => { sensitive?: ->(_document) { true } }) do
      Browse::Cards.send(:example_image, hub("object-types"), candidate, [])
    end

    assert_nil sensitive
  end
end
