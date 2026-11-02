require "test_helper"

# CCS-71: the width and height of a record's image, from the file's header (lib/image_dimensions.rb)
class ImageDimensionsTest < ActiveSupport::TestCase
  test "reads a JPEG's size" do
    assert_equal [ 1279, 1600 ], ImageDimensions.for_path("/digital-assets/large/0000_013_1_pf.jpg")
    assert_equal [ 640, 800 ], ImageDimensions.for_path("/digital-assets/thumbs/0000_013_1_pf.jpg")
  end

  test "reads a PNG's size" do
    assert_equal [ 512, 512 ], ImageDimensions.for_path("/icon.png")
  end

  test "gives nil for a file that is not there, one that is not an image, an address on another host, or a path out of public" do
    assert_nil ImageDimensions.for_path("/digital-assets/large/not-there.jpg")
    assert_nil ImageDimensions.for_path("/icon.svg")
    assert_nil ImageDimensions.for_path("https://example.org/a.jpg")
    assert_nil ImageDimensions.for_path("/../config/database.yml")
    assert_nil ImageDimensions.for_path(nil)
  end
end
