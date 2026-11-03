require "test_helper"
require_relative "../support/discovery_records"

class SimilarRecordsTest < ActiveSupport::TestCase
  include DiscoveryRecords

  def source = SolrDocument.new(open_record("emu-source", "date_start_isi" => 1908))

  def similar_for(document, records:, similar:)
    with_canned_search(discovery_solr(records: records, similar: similar)) { |seen| return [ SimilarRecords.for(document), seen ] }
  end

  test "the query is More Like This on the record's id, with the record excluded, taking the id as a parameter and never in the text" do
    params = SimilarRecords.new(SolrDocument.new(open_record('emu-"1" or *:*'))).params

    assert_includes params[:sim_mlt], "{!mlt qf="
    assert_includes params[:sim_mlt], "v=$src"
    assert_equal 'emu-"1" or *:*', params[:src]
    assert_equal "-{!term f=id v=$src}", params[:fq]
    assert_no_match(/or \*:\*/, params[:q] + params[:sim_mlt])
    assert_includes params[:q], "should=$sim_image"
    assert_includes params[:sim_mlt], "creator_ssim^3.0"
    assert_includes params[:sim_mlt], "mindf=#{SimilarRecords::MIN_DOC_FREQUENCY}"
  end

  test "the date clause is there only for a record with a date, and spans 25 years either side" do
    assert_includes SimilarRecords.new(source).params[:sim_near], "[1883 TO 1933]"
    assert_nil SimilarRecords.new(SolrDocument.new("id" => "x")).params[:sim_near]
  end

  test "the records found come back in score order, without the record itself and without records the sections never list" do
    records = [ open_record("emu-1"), withheld_record("emu-2"), sensitive_record("emu-3"), open_record("emu-4"), open_record("emu-source") ]
    found, = similar_for(source, records: records, similar: { "emu-1" => 50, "emu-2" => 48, "emu-3" => 47, "emu-source" => 46, "emu-4" => 45 })

    assert_equal %w[emu-1 emu-4], found.map(&:id)
  end

  test "a weak match, far below the best, is not similar" do
    records = [ open_record("emu-1"), open_record("emu-2"), open_record("emu-3") ]
    found, = similar_for(source, records: records, similar: { "emu-1" => 100, "emu-2" => 60, "emu-3" => 10 })

    assert_equal %w[emu-1 emu-2], found.map(&:id)
  end

  test "no more than three records of one creator" do
    records = (1..6).map { |n| open_record("emu-#{n}", creator_ssim: [ "Same, Creator" ]) } + [ open_record("emu-7", creator_ssim: [ "Other" ]) ]
    found, = similar_for(source, records: records, similar: records.each_with_index.to_h { |record, n| [ record["id"], 100 - n ] })

    assert_equal %w[emu-1 emu-2 emu-3 emu-7], found.map(&:id)
  end

  test "at most the number shown, and nothing when fewer than two are found" do
    many = (1..10).map { |n| open_record("emu-#{n}", creator_ssim: [ "C#{n}" ]) }
    found, = similar_for(source, records: many, similar: many.to_h { |record| [ record["id"], 50 ] })
    assert_equal SimilarRecords::SHOWN, found.size

    one, = similar_for(source, records: many.first(1), similar: { "emu-1" => 50 })
    assert_equal [], one
  end

  test "a record whose asset is withheld, or that is sensitive, gets no recommendations and asks Solr for none" do
    records = [ open_record("emu-1"), open_record("emu-2") ]
    [ withheld_record("emu-w"), sensitive_record("emu-s") ].each do |hidden|
      found, seen = similar_for(SolrDocument.new(hidden), records: records, similar: { "emu-1" => 50, "emu-2" => 40 })

      assert_equal [], found
      assert_empty seen
    end
  end

  test "Solr failing gives nothing and no error" do
    with_canned_search(->(_params) { raise Faraday::ConnectionFailed, "down" }) { assert_equal [], SimilarRecords.for(source) }
    with_canned_search(->(_params) { raise Blacklight::Exceptions::InvalidRequest, "bad" }) { assert_equal [], SimilarRecords.for(source) }
  end

  test "the real index finds records like a record, and not the record" do
    needs_solr
    document = Discovery.fetch([ "emu-10247" ]).first
    found = SimilarRecords.for(document)

    assert_operator found.size, :>=, SimilarRecords::MINIMUM
    assert_not_includes found.map(&:id), "emu-10247"
    assert(found.all? { |record| Discovery.listable?(record) })
  end
end
