require "test_helper"

class BrowsePeriodsTest < ActiveSupport::TestCase
  def span(period) = [ period.first, period.last, period.kind ]

  test "addresses parse to centuries, decades and everything before 1000" do
    assert_equal [ 1900, 1999, :century ], span(Browse::Periods.parse("1900-1999"))
    assert_equal [ 1920, 1929, :decade ], span(Browse::Periods.parse("1920-1929"))
    assert_equal [ 1900, 1909, :decade ], span(Browse::Periods.parse("1900-1909"))
    assert_equal [ 1000, 1099, :century ], span(Browse::Periods.parse("1000-1099"))
    assert_equal [ nil, 999, :before ], span(Browse::Periods.parse("before-1000"))
  end

  test "anything that is not exactly a period is refused" do
    [ "1900-1950", "1901-2000", "1925-1934", "0-99", "0900-0999", "2100-2199", "bce-500-401", "before-5000-bce", "20th-century",
      "1900-1999/x", "1900--1999", "", nil ].each do |bad|
      assert_nil Browse::Periods.parse(bad), bad.inspect
    end
  end

  test "a period's slug parses back to the same period" do
    [ "1900-1999", "1920-1929", "1000-1099", "before-1000" ].each { |slug| assert_equal slug, Browse::Periods.parse(slug).slug }
  end

  test "the spans of the periods list have pages of their own" do
    assert_equal "before-1000", Browse::Periods.for_span(-10_000, 999).slug
    assert_equal "1500-1599", Browse::Periods.for_span(1500, 1599).slug
    assert_equal "1950-1959", Browse::Periods.for_span(1950, 1959).slug
    assert_nil Browse::Periods.for_span(1500, 1799) # a span of the home page's Explore tiles, not a period of the list
  end

  test "labels are the spans, as the periods list shows them" do
    assert_equal "1900–1999", Browse::Periods.parse("1900-1999").label
    assert_equal "1920–1929", Browse::Periods.parse("1920-1929").label
    assert_equal "Before 1000", Browse::Periods.parse("before-1000").label
  end

  test "the Solr filter and the results page search cover the same years" do
    century = Browse::Periods.parse("1900-1999")

    assert_equal "date_start_isi:[1900 TO 1999]", century.fq
    assert_equal({ begin: 1900, end: 1999 }, century.search_query[:range]["date_start_isi"])
    assert_equal "date_start_isi:[* TO 999]", Browse::Periods.parse("before-1000").fq
    assert_equal({ end: 999 }, Browse::Periods.parse("before-1000").search_query[:range]["date_start_isi"])
  end

  test "a decade belongs to its century" do
    assert_equal "1900-1999", Browse::Periods.parse("1920-1929").parent.slug
    assert_nil Browse::Periods.parse("1900-1999").parent
  end

  test "range keys become periods" do
    assert_equal "1900-1999", Browse::Periods.for_range_start(1900, 100).slug
    assert_equal "1910-1919", Browse::Periods.for_range_start(1910, 10).slug
    assert_equal :before, Browse::Periods.for_range_start(500, 100).kind
  end
end
