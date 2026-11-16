require "test_helper"
require "tmpdir"
require "rake"

# CCS-31: the metadata CSV a staff member prepares (Collections::CsvSource) and its two tasks.
class CsvSourceTest < ActiveSupport::TestCase
  SAMPLE = Rails.root.join("test/fixtures/files/sample-metadata.csv").to_s

  def csv(text, encoding: "UTF-8", bom: false)
    @dir ||= Dir.mktmpdir
    path = File.join(@dir, "t.csv")
    body = text.encode(encoding)
    File.binwrite(path, (bom ? "﻿".encode(encoding) : "") + body)
    Collections::CsvSource.new(path)
  end

  teardown { FileUtils.remove_entry(@dir) if @dir }

  test "the sample file is valid and becomes documents with the same fields as the other sources" do
    source = Collections::CsvSource.new(SAMPLE)
    report = source.check(documents: true)

    assert report.ok?, report.problems.inspect
    assert_equal 2, report.documents.size
    first = report.documents.first
    assert_equal "csv-sample-1", first["id"]
    assert_equal [ "Violin with a label" ], first["title_tsim"]
    assert_equal [ "Stradivari, Antonio", "Smith, J." ], first["creator_ssim"]
    assert_equal 1845, first["date_start_isi"]
    assert_equal [ "Public domain - Copyright expired" ], first["licence_type_ssim"]
    assert_equal [ "zh", "en" ], report.documents.last["language_ssim"]
    assert_equal %w[csv-sample-1 csv-sample-2], source.each_document.map { |document| document["id"] }
  end

  test "headers match without regard to case, spaces or underscores" do
    report = csv("ID,Title,Accession Number\na-1,T,X 1\n").check(documents: true)

    assert report.ok?
    assert_equal [ "X 1" ], report.documents.first["accession_number_ssim"]
  end

  test "a byte-order mark, UTF-16 and Windows-1252 files are all read" do
    [ { bom: true }, { encoding: "UTF-16LE", bom: true }, { encoding: "Windows-1252" } ].each do |options|
      report = csv("id,title\na-1,Café ornement\n", **options).check(documents: true)
      assert_equal [ "Café ornement" ], report.documents.first["title_tsim"], options.inspect
    end
  end

  test "every kind of problem is reported with its line" do
    text = <<~CSV
      id,title,date,mystery,description
      ok-1,Fine,1900,,x
      ,No id,1900,,x
      bad id!,Bad id,1900,,x
      ok-2,,1900,,x
      ok-3,Bad date,someday,,x
      ok-1,Duplicate,1900,,x
      ok-4,Long,1900,,#{'x' * 10_001}
    CSV
    report = csv(text).check
    messages = report.problems.map { |problem| [ problem.line, problem.message ] }

    assert_equal [ "mystery" ], report.unknown_columns
    assert(messages.any? { |line, message| line == 3 && message == "id is missing" })
    assert(messages.any? { |line, message| line == 4 && message.start_with?("id may only") })
    assert(messages.any? { |line, message| line == 5 && message == "title is missing" })
    assert(messages.any? { |line, message| line == 6 && message.start_with?("date") })
    assert(messages.any? { |line, message| line == 7 && message.start_with?("duplicate id") })
    assert(messages.any? { |line, message| line == 8 && message.include?("10001 characters") })
    assert_not report.ok?
  end

  test "missing required columns, a repeated column, an empty file and broken CSV are reported" do
    assert_equal [ "id" ], csv("title\nx\n").check.missing_columns
    assert(csv("id,id,title\na,b,c\n").check.problems.any? { |problem| problem.message.include?("more than once") })
    assert csv("").check.problems.any?
    assert csv("id,title\na,\"unclosed\n").check.problems.any? { |problem| problem.message.start_with?("the file is not valid CSV") }
  end

  test "blank lines are skipped, and a document is made only from a row without problems" do
    report = csv("id,title\n\n,\nok-1,Fine\nbad id,Nope\n").check(documents: true)

    assert_equal 2, report.rows
    assert_equal [ "csv-ok-1" ], report.documents.map { |document| document["id"] }
  end

  # --- the tasks ---

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("records:validate_csv")
    %w[records:validate_csv records:csv_to_documents].each { |name| Rake::Task[name].reenable }
  end

  test "validate_csv prints the problems as CSV (formulas made safe) and exits 1; a good file exits 0" do
    source = csv("id,title\n=bad,=1+1\n")
    out, err = capture_io { assert_raises(SystemExit) { Rake::Task["records:validate_csv"].invoke(source.path) } }

    assert_match(/^line,id,problem/, out)
    assert_match(/'=bad/, out)
    assert_match(/Fix these first/, err)

    Rake::Task["records:validate_csv"].reenable
    _, err = capture_io { Rake::Task["records:validate_csv"].invoke(SAMPLE) }
    assert_match(/2 rows, 0 with problems.*Ready to convert/, err)
  end

  test "csv_to_documents prints JSON, writes OUT, refuses a bad file, and never indexes into the shared Solr" do
    out, = capture_io { Rake::Task["records:csv_to_documents"].invoke(SAMPLE) }
    assert_equal %w[csv-sample-1 csv-sample-2], JSON.parse(out).map { |document| document["id"] }

    Rake::Task["records:csv_to_documents"].reenable
    file = File.join(Dir.mktmpdir, "out.json")
    ENV["OUT"] = file
    capture_io { Rake::Task["records:csv_to_documents"].invoke(SAMPLE) }
    assert_equal 2, JSON.parse(File.read(file)).size

    Rake::Task["records:csv_to_documents"].reenable
    ENV["OUT"] = nil
    ENV["INDEX"] = "1"
    ENV["SOLR_URL"] = "http://127.0.0.1:8984/solr/blacklight-core"
    assert_raises(SystemExit) { capture_io { Rake::Task["records:csv_to_documents"].invoke(SAMPLE) } }

    Rake::Task["records:csv_to_documents"].reenable
    assert_raises(SystemExit) { capture_io { Rake::Task["records:csv_to_documents"].invoke(csv("id\nx\n").path) } }
  ensure
    ENV.delete("OUT"); ENV.delete("INDEX"); ENV["SOLR_URL"] = "http://127.0.0.1:1/solr/blacklight-core"
  end
end
