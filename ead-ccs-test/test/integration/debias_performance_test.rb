require "test_helper"
require_relative "../support/request_counter"
require_relative "../support/debias_helper"

# De-bias notices must not move the record page's budgets (docs/performance.md): with the list empty (as shipped) they cost
# nothing, and a long list costs milliseconds of CPU and no Solr or database request.
class DebiasPerformanceTest < ActionDispatch::IntegrationTest
  include RequestCounter
  include DebiasHelper

  FIELDS = {
    "title_tsim" => [ "Percy Grainger" ], "description_tsim" => [ "Reprint of a booklet originally published in 1927 by an institute press. " * 30 ],
    "subject_ssim" => [ "PHOTOGRAPHY--Photographs Unframed", "Musicians", "Composers" ], "production_place_ssim" => [ "Melbourne" ],
    "material_ssim" => [ "paper" ], "creator_display_ssim" => [ "Grainger, Percy (1882-1961), composer" ]
  }.freeze

  def milliseconds(times)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    times.times { yield }
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000 / times
  end

  test "scanning with the list empty takes microseconds" do
    with_debias_terms do
      assert_operator milliseconds(1000) { DebiasTerms.scan(FIELDS) }, :<, 0.05
    end
  end

  test "scanning a record against 300 terms takes a few milliseconds" do
    terms = (1..300).map { |i| debias_entry("fakeword#{i}x") }
    with_debias_terms(*terms) do
      DebiasTerms.scan(FIELDS) # compiles the matchers once, as the first request would
      assert_operator milliseconds(20) { DebiasTerms.scan(FIELDS) }, :<, 25
    end
  end

  test "a flagged record page makes the same Solr and database requests as an unflagged one" do
    needs_solr
    get "/catalog/emu-406126"
    plain = count_requests { get "/catalog/emu-406126" }

    with_debias_terms("grainger") do
      flagged = count_requests { get "/catalog/emu-406126" }

      assert_select "aside.record-debias", 1
      assert_equal [ plain.solr, plain.sql ], [ flagged.solr, flagged.sql ]
    end
  end
end
