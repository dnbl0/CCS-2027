require "test_helper"
require "csv"
require "rake"

# bin/rails records:suppress, records:unsuppress, records:suppressed (CCS-112): how staff take a record out of the site and bring it back.
class RecordsTasksTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("records:suppress")
    SuppressedRecord.delete_all
    %w[records:suppress records:unsuppress records:suppressed records:remove_csv].each { |name| Rake::Task[name].reenable }
  end

  def run_task(name, *args)
    out, err = capture_io { Rake::Task[name].invoke(*args) }
    Rake::Task[name].reenable
    [ out, err ]
  end

  test "suppress takes a record out with its reason, and says so; again it only updates the reason" do
    out, = run_task("records:suppress", "emu-1", "Family asked, in writing")

    assert_match(/emu-1 is removed from the site/, out)
    assert SuppressedRecord.suppressed?("emu-1")
    assert_equal "Family asked, in writing", SuppressedRecord.find_by!(record_id: "emu-1").reason

    out, = run_task("records:suppress", "emu-1", "New reason")
    assert_match(/already removed/, out)
    assert_equal 1, SuppressedRecord.count
  end

  test "a reason with commas, as rake splits it, is put back together without its quotes" do
    Rake::Task["records:suppress"].invoke("emu-1", "\"Because one", " two\"")

    assert_equal "Because one, two", SuppressedRecord.find_by!(record_id: "emu-1").reason
  end

  test "suppress refuses an id that is not a record id, and a missing reason, and changes nothing" do
    assert_raises(SystemExit) { capture_io { Rake::Task["records:suppress"].invoke("a b", "why") } }
    Rake::Task["records:suppress"].reenable
    assert_raises(SystemExit) { capture_io { Rake::Task["records:suppress"].invoke("emu-1") } }

    assert_equal 0, SuppressedRecord.count
  end

  test "CCS-31: remove_csv takes every record of an uploaded CSV out of the site (csv-<id>), with one reason; one can be put back" do
    file = Tempfile.new([ "upload", ".csv" ])
    file.write("ID,Title\nA1,First\nA2,Second\nB:3,Third\n,\n")
    file.close
    out, = run_task("records:remove_csv", file.path, "Superseded by EMu")

    assert_match(/3 records removed/, out)
    assert SuppressedRecord.suppressed?("csv-B_3") # the id as the CSV source indexes it
    assert SuppressedRecord.suppressed?("csv-A1")
    assert SuppressedRecord.suppressed?("csv-A2")
    assert_equal "Superseded by EMu", SuppressedRecord.find_by!(record_id: "csv-A2").reason

    run_task("records:unsuppress", "csv-A1")
    assert_not SuppressedRecord.suppressed?("csv-A1")
  ensure
    file&.unlink
  end

  test "unsuppress puts a record back, and is safe to repeat" do
    SuppressedRecord.suppress!("emu-1", reason: "r")

    out, = run_task("records:unsuppress", "emu-1")
    assert_match(/emu-1 is back/, out)
    out, = run_task("records:unsuppress", "emu-1")
    assert_match(/was not removed/, out)
    assert_not SuppressedRecord.suppressed?("emu-1")
  end

  test "suppressed lists them as CSV, with a reason that starts like a formula made safe" do
    SuppressedRecord.suppress!("emu-1", reason: "=1+1 and, a comma", by: "Dean")

    out, = run_task("records:suppressed")
    rows = CSV.parse(out, headers: true)

    assert_equal %w[record_id suppressed_at suppressed_by reason], rows.headers
    assert_equal [ "emu-1" ], rows.map { |row| row["record_id"] }
    assert_equal "'=1+1 and, a comma", rows.first["reason"]
  end
end
