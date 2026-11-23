require "test_helper"

class DamImageTest < ActiveSupport::TestCase
  test "a DAM picture is asked for at the width given; any other address is left as it is" do
    dam = "https://unimelbourne.widen.net/content/k9/jpeg/a.jpeg?w=1000&position=c&quality=100"
    assert_equal "https://unimelbourne.widen.net/content/k9/jpeg/a.jpeg?w=600&position=c&quality=100", DamImage.sized(dam, 600)
    assert_equal "/film-thumbs/a.jpg", DamImage.sized("/film-thumbs/a.jpg", 600)
    assert_equal "https://example.test/a.jpg?w=1000", DamImage.sized("https://example.test/a.jpg?w=1000", 600)
    assert_equal "https://unimelbourne.widen.net/a.jpg", DamImage.sized("https://unimelbourne.widen.net/a.jpg", 600) # no width to change
  end
end
