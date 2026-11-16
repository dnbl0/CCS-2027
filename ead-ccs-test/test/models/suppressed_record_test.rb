require "test_helper"

# CCS-112: the list of records taken out of the site, and what is built from it.
class SuppressedRecordTest < ActiveSupport::TestCase
  setup { SuppressedRecord.forget! }
  teardown { SuppressedRecord.forget! }

  test "a record id has letters, digits and . _ : - only" do
    %w[emu-1 vernon-MHM00394 a.b_c:d-9].each { |id| assert SuppressedRecord.valid_id?(id), id }
    [ "", " ", "a b", "a,b", "-x", "a/b", "a\"b", "a}b", "x" * 201 ].each { |id| assert_not SuppressedRecord.valid_id?(id), id.inspect }
    assert_not SuppressedRecord.new(record_id: "a,b", reason: "r").valid?
    assert_not SuppressedRecord.new(record_id: "emu-1", reason: " ").valid?
  end

  test "suppressing is idempotent: again changes the reason, never the date, and there is one row" do
    first = SuppressedRecord.suppress!("emu-1", reason: "Family asked", by: "Dean")
    date = first.suppressed_at
    again = SuppressedRecord.suppress!("emu-1", reason: "Legal advice")

    assert_equal 1, SuppressedRecord.where(record_id: "emu-1").count
    assert_equal date, again.reload.suppressed_at
    assert_equal "Legal advice", again.reason
    assert_equal "Dean", again.suppressed_by, "who is kept when the second call does not say"
  end

  test "unsuppressing says whether there was anything to lift, and is safe to repeat" do
    SuppressedRecord.suppress!("emu-1", reason: "r")

    assert SuppressedRecord.unsuppress!("emu-1")
    assert_not SuppressedRecord.unsuppress!("emu-1")
    assert_not SuppressedRecord.suppressed?("emu-1")
  end

  test "the list is seen at once in the process that changed it" do
    assert_not SuppressedRecord.suppressed?("emu-1")
    SuppressedRecord.suppress!("emu-1", reason: "r")

    assert SuppressedRecord.suppressed?("emu-1")
    assert_raises(SuppressedRecord::Removed) { SuppressedRecord.guard!("emu-1") }
    assert_nothing_raised { SuppressedRecord.guard!("emu-2") }
  end

  test "another process's change is seen within the cache time" do
    assert_not SuppressedRecord.suppressed?("emu-1")
    SuppressedRecord.insert!({ record_id: "emu-1", reason: "r", suppressed_at: Time.current, created_at: Time.current, updated_at: Time.current }) # no callback, as another process
    assert_not SuppressedRecord.suppressed?("emu-1"), "still the list read a moment ago"

    ENV["SUPPRESSED_RECORDS_CACHE_SECONDS"] = "0"
    assert SuppressedRecord.suppressed?("emu-1")
  ensure
    ENV.delete("SUPPRESSED_RECORDS_CACHE_SECONDS")
  end

  test "the Solr filter leaves the records out, and there is none when nothing is suppressed" do
    assert_nil SuppressedRecord.solr_filter

    SuppressedRecord.suppress!("emu-2", reason: "r")
    SuppressedRecord.suppress!("emu-1", reason: "r")

    assert_equal "-{!terms f=id}emu-1,emu-2", SuppressedRecord.solr_filter
  end

  test "cache keys are unchanged while nothing is suppressed, and change with the list" do
    assert_equal "browse/x", SuppressedRecord.cache_key("browse/x")

    SuppressedRecord.suppress!("emu-1", reason: "r")
    one = SuppressedRecord.cache_key("browse/x")
    SuppressedRecord.suppress!("emu-2", reason: "r")
    two = SuppressedRecord.cache_key("browse/x")
    SuppressedRecord.unsuppress!("emu-2")

    assert_not_equal "browse/x", one
    assert_not_equal one, two
    assert_equal one, SuppressedRecord.cache_key("browse/x"), "the same list, the same key"
  end

  test "if the database cannot be read the last list stands" do
    SuppressedRecord.suppress!("emu-1", reason: "r")
    SuppressedRecord.ids
    ENV["SUPPRESSED_RECORDS_CACHE_SECONDS"] = "0"
    SuppressedRecord.singleton_class.send(:define_method, :order) { |*| raise ActiveRecord::ConnectionNotEstablished, "down" }
    assert SuppressedRecord.suppressed?("emu-1")
  ensure
    SuppressedRecord.singleton_class.send(:remove_method, :order)
    ENV.delete("SUPPRESSED_RECORDS_CACHE_SECONDS")
  end
end
