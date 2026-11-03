require "test_helper"
require_relative "../support/discovery_records"

# The curated picks (config/featured.yml) and the Pick of the day
class FeaturedRecordsTest < ActiveSupport::TestCase
  include DiscoveryRecords

  def pool(count = 20) = (1..count).map { |n| open_record(format("emu-%03d", n)) }

  test "config/featured.yml lists unique ids with short blurbs marked as placeholders" do
    picks = FeaturedRecords.configured

    assert_operator picks.size, :>=, 6
    ids = picks.map { |pick| pick["id"] }
    assert_equal ids.uniq, ids
    picks.each do |pick|
      assert_match(/\A[\w.-]+\z/, pick["id"])
      assert_operator pick["blurb"].to_s.length, :<=, 140
      assert_match(/placeholder/i, pick["blurb"].to_s, "blurbs are placeholder wording until the collection teams supply text")
    end
  end

  test "every curated pick is in the index, may be listed and has an image" do
    needs_solr
    documents = Discovery.fetch(FeaturedRecords.configured.map { |pick| pick["id"] })

    assert_equal FeaturedRecords.configured.size, documents.size, "a pick in config/featured.yml is not in the index"
    documents.each do |document|
      assert Discovery.listable?(document), "#{document.id} is withheld or sensitive, so no section would show it"
      assert document["thumbnail_path_ssi"].present?, "#{document.id} has no image"
    end
  end

  test "picks come back in the configured order, with their blurbs, and leave out records that may not be listed or are missing" do
    ids = FeaturedRecords.configured.first(4).map { |pick| pick["id"] }
    records = [ open_record(ids[2]), withheld_record(ids[1]), open_record(ids[0]), sensitive_record(ids[3]) ]

    with_canned_search(discovery_solr(records: records)) do
      picks = FeaturedRecords.picks(limit: 12)

      assert_equal [ ids[0], ids[2] ], picks.map { |entry| entry.document.id }
      assert_match(/placeholder/i, picks.first.blurb)
    end
  end

  test "Solr failing leaves no picks and no error" do
    with_canned_search(->(_params) { raise Blacklight::Exceptions::ECONNREFUSED, "down" }) do
      assert_equal [], FeaturedRecords.picks
      assert_nil FeaturedRecords.pick_of_the_day
    end
  end

  test "the Pick of the day is the same record all day, and varies from day to day" do
    with_canned_search(discovery_solr(records: pool)) do
      today = Date.new(2026, 11, 3)
      first = FeaturedRecords.pick_of_the_day(today)

      assert_equal first.id, FeaturedRecords.pick_of_the_day(today).id
      week = (0..6).map { |offset| FeaturedRecords.pick_of_the_day(today + offset).id }
      assert_operator week.uniq.size, :>, 1, "seven days gave the same record"
    end
  end

  test "the day's position is the date's CRC32 modulo the pool, so it is the same in every process" do
    records = pool
    day = Date.new(2026, 1, 15)
    expected = records.sort_by { |record| record["id"] }[Zlib.crc32("pick-of-the-day-2026-01-15") % records.size]["id"]

    with_canned_search(discovery_solr(records: records)) { assert_equal expected, FeaturedRecords.pick_of_the_day(day).id }
  end

  test "only a record with an image anyone may download is picked: not view-only, not withheld, not sensitive, not without an image" do
    records = [ view_only_record("emu-001"), withheld_record("emu-002"), sensitive_record("emu-003"), open_record("emu-004", thumbnail_path_ssi: nil),
                open_record("emu-005") ]

    with_canned_search(discovery_solr(records: records)) do
      365.times { |offset| assert_equal "emu-005", FeaturedRecords.pick_of_the_day(Date.new(2026, 1, 1) + offset)&.id }
    end
  end

  test "a sensitive record that reaches the picker through a mixed licence is skipped for the next one" do
    mixed = open_record("emu-001", licence_type_ssim: [ "Public domain - Copyright expired", "Copyright - Current" ]) # the stricter tier wins: view-only
    with_canned_search(->(params) { params[:rows].to_i.zero? ? canned_response([], total: 2) : canned_response([ mixed, open_record("emu-002") ]) }) do
      assert_equal "emu-002", FeaturedRecords.pick_of_the_day(Date.new(2026, 5, 5)).id
    end
  end

  test "an empty pool gives no pick" do
    with_canned_search(discovery_solr(records: [])) { assert_nil FeaturedRecords.pick_of_the_day }
  end

  test "the Pick of the day is a record of the real index with a downloadable image" do
    needs_solr
    pick = FeaturedRecords.pick_of_the_day(Date.new(2026, 11, 3))

    assert pick, "the index has no record with an open-tier image"
    assert Discovery.pickable?(pick)
  end
end
