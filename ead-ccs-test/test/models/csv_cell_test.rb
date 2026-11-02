require "test_helper"

class CsvCellTest < ActiveSupport::TestCase
  test "a cell that a spreadsheet would run as a formula gets a leading apostrophe" do
    [ "=SUM(A1)", "+1+1", "-2+3", "@cmd", "\t=1", "\r=1", "=HYPERLINK(\"http://evil\",\"x\")" ].each do |value|
      assert_equal "'#{value}", CsvCell.safe(value)
    end
  end

  test "other text, blanks and non-strings are left as they are" do
    assert_equal "Percy Grainger", CsvCell.safe("Percy Grainger")
    assert_equal "a=b", CsvCell.safe("a=b")
    assert_equal "", CsvCell.safe(nil)
    assert_equal "1850", CsvCell.safe(1850)
    assert_equal "Wurundjeri Māori", CsvCell.safe("Wurundjeri Māori")
  end
end
