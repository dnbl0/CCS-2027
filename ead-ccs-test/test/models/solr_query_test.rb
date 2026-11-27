# frozen_string_literal: true

require "test_helper"

# The one way to put a value into Solr query text (SolrQuery): a quoted phrase whose quotes and backslashes are escaped
class SolrQueryTest < ActiveSupport::TestCase
  test "a phrase is quoted, with its quotes and backslashes escaped, so no value can end it" do
    assert_equal '"Lees, Derwent"', SolrQuery.phrase("Lees, Derwent")
    assert_equal '"x\" OR *:*"', SolrQuery.phrase('x" OR *:*')
    assert_equal '"a\\\\b"', SolrQuery.phrase('a\\b')
    assert_equal '"1910"', SolrQuery.phrase(1910)
  end

  test "a field query matches any of its values" do
    assert_equal 'creator_ssim:("A" OR "B \"C\"")', SolrQuery.field("creator_ssim", [ "A", 'B "C"' ])
    assert_equal 'id:("emu-1")', SolrQuery.field("id", "emu-1")
  end
end
