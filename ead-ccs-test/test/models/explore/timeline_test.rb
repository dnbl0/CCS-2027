require "test_helper"

class Explore::TimelineTest < ActiveSupport::TestCase
  OPEN = { "id" => "r1", "title_tsim" => [ "Open print" ], "thumbnail_path_ssi" => "https://example.org/r1.jpg", "has_digital_asset_bsi" => true,
           "licence_type_ssim" => [ "Public domain - Copyright expired" ] }.freeze
  WITHHELD = { "id" => "r2", "title_tsim" => [ "Withheld" ], "thumbnail_path_ssi" => "https://example.org/r2.jpg", "licence_type_ssim" => [ "ICIP Rights" ] }.freeze

  # Answers the counts request and the grouped pictures request
  class Connection
    attr_reader :requests

    def initialize(counts:, eras: {}, before: 0, docs: [])
      @counts = counts
      @eras = eras
      @before = before
      @docs = docs
      @requests = []
    end

    def get(_path, params:)
      @requests << params
      if params[:group]
        { "grouped" => params[:"group.query"].to_h { |query| [ query, { "doclist" => { "docs" => @docs } } ] } }
      else
        { "facet_counts" => { "facet_ranges" => { "date_start_isi" => { "counts" => @counts.flat_map { |k, v| [ k.to_s, v ] }, "before" => @before } },
                              "facet_fields" => { "date_era_ssim" => @eras.flat_map { |k, v| [ k, v ] } } } }
      end
    end
  end

  def build(connection, century: nil) = Explore::Timeline.new(connection, 2026).build(century)

  test "centuries from a range facet, BCE years negative, earliest first, empty ones left out, with an earlier-than period" do
    connection = Connection.new(counts: { -500 => 4, 1800 => 0, 1900 => 120 }, before: 2)
    result = build(connection)

    assert_equal [ "Before 3000 BCE", "500–401 BCE", "1900–1999" ], result.periods.map(&:label)
    assert_equal [ 2, 4, 120 ], result.periods.map(&:count)
    params = connection.requests.first
    assert_equal [ -3000, 2100, 100, "before" ], params.values_at(:"f.date_start_isi.facet.range.start", :"f.date_start_isi.facet.range.end",
                                                                   :"f.date_start_isi.facet.range.gap", :"f.date_start_isi.facet.range.other")
  end

  test "a period opens the search with the range filter" do
    period = build(Connection.new(counts: { 1900 => 1 })).periods.first
    assert_equal({ "date_start_isi" => { begin: 1900, end: 1999 } }, period.search_query[:range])
    assert_equal({ end: -3001 }, build(Connection.new(counts: {}, before: 1)).periods.first.search_query[:range]["date_start_isi"])
  end

  test "a century's decades" do
    result = build(Connection.new(counts: { 1920 => 5, 1930 => 7 }), century: 1900)
    assert_equal [ "1920–1929", "1930–1939" ], result.periods.map(&:label)
    assert_not result.periods.first.century?
  end

  test "pictures only from records a visitor may see" do
    images = build(Connection.new(counts: { 1900 => 2 }, docs: [ WITHHELD, OPEN ])).periods.first.images
    assert_equal [ "r1" ], images.map(&:id)
  end

  test "eras in order of time, those without a century last" do
    eras = build(Connection.new(counts: {}, eras: { "20th century" => 3, "5th century BC" => 1, "Edwardian" => 2, "Unknown" => 9 })).eras
    assert_equal [ "5th century BC", "20th century", "Edwardian" ], eras.map(&:name)
  end

  test "only a whole century is a zoom" do
    assert_equal 1900, Explore::Timeline.century_param("1900")
    assert_equal(-500, Explore::Timeline.century_param("-500"))
    assert_nil Explore::Timeline.century_param("1950")
    assert_nil Explore::Timeline.century_param("abc")
  end
end
