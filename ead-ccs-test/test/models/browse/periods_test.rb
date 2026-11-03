require "test_helper"

class BrowsePeriodsTest < ActiveSupport::TestCase
  def span(period) = [ period.first, period.last, period.kind ]

  test "addresses parse to centuries, decades, BCE centuries and the earliest period" do
    assert_equal [ 1900, 1999, :century ], span(Browse::Periods.parse("1900-1999"))
    assert_equal [ 1920, 1929, :decade ], span(Browse::Periods.parse("1920-1929"))
    assert_equal [ 1900, 1909, :decade ], span(Browse::Periods.parse("1900-1909"))
    assert_equal [ 0, 99, :century ], span(Browse::Periods.parse("0-99"))
    assert_equal [ -500, -401, :bce_century ], span(Browse::Periods.parse("bce-500-401"))
    assert_equal :before, Browse::Periods.parse("before-5000-bce").kind
  end

  test "anything that is not exactly a period is refused" do
    [ "1900-1950", "1901-2000", "1925-1934", "bce-500-402", "bce-550-451", "bce-9000-8901", "before-4000-bce", "2100-2199", "20th-century",
      "1900-1999/x", "1900--1999", "", nil ].each do |bad|
      assert_nil Browse::Periods.parse(bad), bad.inspect
    end
  end

  test "a period's slug parses back to the same period" do
    [ "1900-1999", "1920-1929", "0-99", "bce-100-1", "bce-5000-4901", "before-5000-bce" ].each do |slug|
      assert_equal slug, Browse::Periods.parse(slug).slug
    end
  end

  test "labels" do
    assert_equal "1900s", Browse::Periods.parse("1900-1999").label
    assert_equal "1920s", Browse::Periods.parse("1920-1929").label
    assert_equal "1900–1909", Browse::Periods.parse("1900-1909").label
    assert_equal "0–99 CE", Browse::Periods.parse("0-99").label
    assert_equal "500–401 BCE", Browse::Periods.parse("bce-500-401").label
    assert_equal "Before 5,000 BCE", Browse::Periods.parse("before-5000-bce").label
  end

  test "the Solr filter and the results page search cover the same years" do
    century = Browse::Periods.parse("1900-1999")

    assert_equal "date_start_isi:[1900 TO 1999]", century.fq
    assert_equal({ begin: 1900, end: 1999 }, century.search_query[:range]["date_start_isi"])
    assert_equal "date_start_isi:[* TO -5001]", Browse::Periods.parse("before-5000-bce").fq
    assert_equal({ end: -5001 }, Browse::Periods.parse("before-5000-bce").search_query[:range]["date_start_isi"])
  end

  test "a decade belongs to its century" do
    assert_equal "1900-1999", Browse::Periods.parse("1920-1929").parent.slug
    assert_nil Browse::Periods.parse("1900-1999").parent
  end

  test "range keys become periods" do
    assert_equal "1900-1999", Browse::Periods.for_range_start(1900, 100).slug
    assert_equal "1910-1919", Browse::Periods.for_range_start(1910, 10).slug
    assert_equal "bce-500-401", Browse::Periods.for_range_start(-500, 100).slug
    assert_equal :before, Browse::Periods.for_range_start(-5100, 100).kind
  end
end
