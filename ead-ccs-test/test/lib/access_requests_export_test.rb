require "test_helper"
require "csv"
require "rake"

# bin/rails access_requests:export: the pending requests as CSV, for staff until there is an admin screen. Fake data only.
class AccessRequestsExportTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("access_requests:export")
    AccessRequest.delete_all
  end

  def make(status:, name:, purpose: "Fake purpose")
    AccessRequest.create!(document_id: "emu-1", document_identifier: "Grainger Museum Collection, UoM ID emu-umc-1", document_title: "Fake, record", request_type: "view", name: name,
                          email: "fake@example.invalid", purpose: purpose, status: status)
  end

  test "prints a header and the pending requests only, with commas and line breaks quoted" do
    make(status: "pending", name: "Pending Person", purpose: "Line one,\nline two")
    make(status: "approved", name: "Approved Person")

    output, = capture_io { Rake::Task["access_requests:export"].execute }
    rows = CSV.parse(output, headers: true)

    assert_equal %w[id requested_at request_type document_id document_identifier document_title name email organisation purpose], rows.headers
    assert_equal [ "Pending Person" ], rows.map { |row| row["name"] }
    assert_equal "Line one,\nline two", rows.first["purpose"]
    assert_equal "Fake, record", rows.first["document_title"]
    assert_equal "Grainger Museum Collection, UoM ID emu-umc-1", rows.first["document_identifier"]
  end
end
