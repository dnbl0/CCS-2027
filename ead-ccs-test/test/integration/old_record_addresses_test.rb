# frozen_string_literal: true

require "test_helper"

# The October trial record pages (/stock/:id and /branded-stock/:id) were removed on 27 Nov 2026: an old link or bookmark opens
# the record's own page instead of a 404. No Solr is needed: the redirect happens in the router.
class OldRecordAddressesTest < ActionDispatch::IntegrationTest
  test "an old trial record address, or its citation, moves permanently to the record's own page" do
    { "/stock/emu-9044" => "/catalog/emu-9044", "/branded-stock/vernon-MHM00394" => "/catalog/vernon-MHM00394",
      "/stock/emu-9044/citation" => "/catalog/emu-9044" }.each do |old, record|
      get old

      assert_response :moved_permanently, old
      assert_equal "http://www.example.com#{record}", response.location, old
    end
  end
end
