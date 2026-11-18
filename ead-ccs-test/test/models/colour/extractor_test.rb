require "test_helper"
require_relative "../../support/colour_fakes"

# rake colour:extract (Colour::Extractor): resumable, rate-limited, every failure reported. No image is downloaded: the fetcher is a stub.
class Colour::ExtractorTest < ActiveSupport::TestCase
  include ColourFixtures

  DOCS = [ { id: "r1", thumbnail_path_ssi: "https://unimelbourne.widen.net/content/r1/jpeg/r1.jpg" },
           { id: "r2", thumbnail_path_ssi: "https://unimelbourne.widen.net/content/r2/jpeg/r2.jpg" },
           { id: "bad", thumbnail_path_ssi: "https://example.com/bad.jpg" } ].freeze

  def extractor(docs = DOCS, **options)
    @slept = []
    @fetched = []
    images = { "r1" => colour_fixture("red_blue.png"), "r2" => colour_fixture("yellow_palette.png") }
    get = lambda do |uri|
      @fetched << uri.to_s
      [ 200, "image/png", images.fetch(uri.path.split("/")[2]) ]
    end
    @csv = Rails.root.join("tmp/test-colour-failures-#{Process.pid}.csv")
    Colour::Extractor.new(solr: FakeWritableCore.new(docs), fetcher: Colour::Fetcher.new(get: get), rate: 2, failures_csv: @csv,
                          logger: Logger.new(nil), sleeper: ->(seconds) { @slept << seconds }, **options)
  end

  teardown { FileUtils.rm_f(@csv) if @csv }

  test "every record with an image gets its palette, names and histogram; a refused address is recorded and reported" do
    report = extractor.run

    assert_equal [ 3, 2, 0, 1 ], [ report.seen, report.extracted, report.skipped, report.failed ]
    red_blue = RecordColour.find_by!(record_id: "r1")
    assert_equal %w[red blue], red_blue.buckets
    assert_equal "#d62828", red_blue.palette.first["hex"]
    assert_equal DOCS[0][:thumbnail_path_ssi], red_blue.image_url
    assert_equal %w[yellow], RecordColour.find_by!(record_id: "r2").buckets
    assert_match(/Refused/, RecordColour.find_by!(record_id: "bad").error)
    assert_includes File.read(@csv), "bad,https://example.com/bad.jpg"
    assert_match(/3 records with an image: 2 read, 0 already done, 1 could not be read/, report.to_s)
    assert_equal 2, @fetched.size
    assert_equal 1, @slept.size, "the second request waits (2 a second)"
  end

  test "a second run skips what is done, retries failures, and does a record again when its image changed" do
    extractor.run
    changed = DOCS.map(&:dup)
    changed[1][:thumbnail_path_ssi] = "https://unimelbourne.widen.net/content/r2/jpeg/new.jpg"
    report = extractor(changed).run

    assert_equal [ 1, 1, 1 ], [ report.skipped, report.extracted, report.failed ]
    assert_equal 1, @fetched.size
    assert_equal 3, RecordColour.count
  end

  test "FRESH does everything again; LIMIT stops early" do
    extractor.run
    assert_equal 2, extractor(fresh: true).run.extracted
    assert_equal 1, extractor(fresh: true, limit: 1).run.extracted
  end

  test "it refuses to run without DAM_SOLR_URL" do
    ENV.delete("DAM_SOLR_URL")
    assert_raises(Dam::Error) { WritableCore.connect }
  end
end
