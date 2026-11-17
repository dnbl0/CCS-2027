require "test_helper"
require_relative "../support/discovery_records"

# The labelled rows under a record (More by this creator, From the same period, From the same place, More of this type):
# docs/similar-and-trending.md. Solr is stood in for (DiscoveryRecords), with stubbed records that carry the fields a local core
# may lack (date_era_ssim, region_ssim).
class SimilarRowsTest < ActiveSupport::TestCase
  include DiscoveryRecords

  def source(**extra)
    SolrDocument.new(open_record("emu-source", creator_ssim: [ "Lees, Derwent" ], date_era_ssim: [ "20th century" ], region_ssim: [ "Oceania" ],
                                 production_place_ssim: [ "Melbourne" ], object_type_ssim: [ "drawing" ], classification_ssim: [ "Fine Art" ],
                                 date_start_isi: 1910, **extra))
  end

  def row_for(document, key, found:)
    answer = lambda do |params|
      params = params.to_h.with_indifferent_access
      params[:similar_row] ? canned_response(found) : canned_response([])
    end
    with_canned_search(answer) { |seen| return [ SimilarRows.for(document, key), seen ] }
  end

  test "a row is offered only for what the record has; noise such as Unknown is not a creator" do
    assert_equal %w[creator period place type], SimilarRows.keys_for(source)
    assert_equal %w[period place type], SimilarRows.keys_for(source(creator_ssim: [ "Unknown" ]))
    assert_equal [], SimilarRows.keys_for(SolrDocument.new("id" => "bare"))
  end

  test "the period row reads the era or, without one, the start year" do
    assert_includes SimilarRows.keys_for(source(date_era_ssim: nil)), "period"
    assert_not_includes SimilarRows.keys_for(source(date_era_ssim: nil, date_start_isi: nil)), "period"
  end

  test "the query takes every value as a parameter, never in its text, and asks only for listable records with images" do
    params = SimilarRows.new(source(creator_ssim: [ 'x" OR *:*' ]), "creator").params

    assert_equal "creator", params[:similar_row]
    assert_match(/\A\{!bool should=\$sim_r0\}\z/, params[:q])
    assert_equal "{!term f=creator_ssim v=$sim_v0}", params[:sim_r0]
    assert_equal 'x" OR *:*', params[:sim_v0]
    assert_equal "-{!term f=id v=$src}", params[:fq].first
    SimilarRecords::ASSET_FILTERS.each { |filter| assert_includes params[:fq], filter }
  end

  test "each row matches on the first field the record has: era, else 25 years either side; region, else place; object type, else classification" do
    period = SimilarRows.new(source, "period").params
    assert_equal "{!term f=date_era_ssim v=$sim_v0}", period[:sim_r0]
    assert_nil period[:sim_r1]
    assert_equal "date_start_isi:[1885 TO 1935]", SimilarRows.new(source(date_era_ssim: nil), "period").params[:sim_r0]

    assert_equal "{!term f=region_ssim v=$sim_v0}", SimilarRows.new(source, "place").params[:sim_r0]
    assert_equal "{!term f=production_place_ssim v=$sim_v0}", SimilarRows.new(source(region_ssim: nil), "place").params[:sim_r0]

    assert_equal "{!term f=object_type_ssim v=$sim_v0}", SimilarRows.new(source, "type").params[:sim_r0]
    assert_nil SimilarRows.new(source, "type").params[:sim_r1]
    assert_equal "{!term f=classification_ssim v=$sim_v0}", SimilarRows.new(source(object_type_ssim: nil), "type").params[:sim_r0]
  end

  test "up to eight records, without the record itself, withheld, sensitive or imageless ones" do
    found = [ open_record("emu-source"), withheld_record("emu-w"), sensitive_record("emu-s"), open_record("emu-noimage", thumbnail_path_ssi: nil) ] +
            (1..10).map { |n| open_record("emu-#{n}", creator_ssim: [ "C#{n}" ]) }
    documents, = row_for(source, "type", found: found)

    assert_equal (1..8).map { |n| "emu-#{n}" }, documents.map(&:id)
  end

  test "an empty row is nothing, and so is a row the record has no values for (no request is made)" do
    documents, = row_for(source, "creator", found: [])
    assert_equal [], documents

    documents, seen = row_for(source(creator_ssim: nil), "creator", found: [ open_record("emu-1") ])
    assert_equal [], documents
    assert_empty seen
  end

  test "a withheld or sensitive record has no rows and asks for none" do
    [ SolrDocument.new(withheld_record("emu-w", creator_ssim: [ "A" ])), SolrDocument.new(sensitive_record("emu-s", creator_ssim: [ "A" ])) ].each do |hidden|
      assert_equal [], SimilarRows.keys_for(hidden)
      documents, seen = row_for(hidden, "creator", found: [ open_record("emu-1") ])
      assert_equal [], documents
      assert_empty seen
    end
  end

  test "records the page already lists can be left out" do
    documents = with_canned_search(canned_response([ open_record("emu-1"), open_record("emu-2") ])) do
      SimilarRows.for(source, "creator", exclude: [ "emu-1" ])
    end
    assert_equal %w[emu-2], documents.map(&:id)
  end

  test "Solr failing gives nothing and no error" do
    with_canned_search(->(_params) { raise Faraday::ConnectionFailed, "down" }) { assert_equal [], SimilarRows.for(source, "creator") }
  end

  test "See all is the filtered search for a single value, and nothing when the row matches several or a span of years" do
    assert_equal({ "f" => { "creator_ssim" => [ "Lees, Derwent" ] } }, SimilarRows.new(source, "creator").see_all_query)
    assert_equal({ "f" => { "region_ssim" => [ "Oceania" ] } }, SimilarRows.new(source, "place").see_all_query)
    assert_nil SimilarRows.new(source(region_ssim: %w[Oceania Europe]), "place").see_all_query
    assert_nil SimilarRows.new(source(date_era_ssim: nil), "period").see_all_query
  end
end
