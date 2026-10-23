require "test_helper"

class AccessionNumberTest < ActiveSupport::TestCase
  GRAINGER = "Grainger Museum Collection".freeze

  test "a Grainger number the export turned into a decimal gets its zeros back (00.0070, not 0.007)" do
    assert_equal "00.0070", Collections::AccessionNumber.restore("0.007", GRAINGER)
    assert_equal "00.0071", Collections::AccessionNumber.restore("0.0071", GRAINGER)
    assert_equal "01.0011", Collections::AccessionNumber.restore("1.0011", GRAINGER)
    assert_equal "10.0100", Collections::AccessionNumber.restore("10.01", GRAINGER)
  end

  test "a Grainger number that is already whole, or has parts or words, is left as it is" do
    [ "17.0054", "01.3524.1", "01.0422 RETIRED", "01.0796a", "001.55405 RECO" ].each do |number|
      assert_equal number, Collections::AccessionNumber.restore(number, GRAINGER)
    end
  end

  test "other collections are left as they are (the Art Collection's numbers have another shape)" do
    assert_equal "0.0013", Collections::AccessionNumber.restore("0.0013", "University Art Collection")
  end
end
