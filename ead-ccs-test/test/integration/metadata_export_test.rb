require "test_helper"
require "csv"

# CCS-163: a record's metadata as CSV, for the :open tier (public domain) only
class MetadataExportTest < ActionDispatch::IntegrationTest
  OPEN = "emu-9044"            # Public domain - Copyright expired
  VIEW_ONLY = "emu-20335"      # Copyright - Current

  test "an open record's page offers Download metadata (CSV), and the link gives the file" do
    get "/catalog/#{OPEN}"
    assert_select "a[href='/catalog/#{OPEN}/metadata']", text: "Download metadata (CSV)"

    get "/catalog/#{OPEN}/metadata"
    assert_response :success
    assert_equal "text/csv; charset=utf-8", response.headers["Content-Type"]
    assert_match(/attachment; filename="ccs-emu-9044-metadata.csv"/, response.headers["Content-Disposition"])

    header, row = CSV.parse(response.body.delete_prefix("﻿"))
    assert_equal "UoM ID", header.first
    assert_equal "emu-umc-9044", row.first
    assert_equal "http://www.example.com/catalog/#{OPEN}", row[header.index("Persistent link")]
    assert_equal "Public domain - Copyright expired", row[header.index("Licence")]
  end

  test "a view-only record is not offered the export, and its address is a 404" do
    get "/catalog/#{VIEW_ONLY}"
    assert_select "a[href$='/metadata']", count: 0

    get "/catalog/#{VIEW_ONLY}/metadata"
    assert_response :not_found
  end

  test "an unknown record is a 404" do
    get "/catalog/no-such-record/metadata"
    assert_response :not_found
  end
end
