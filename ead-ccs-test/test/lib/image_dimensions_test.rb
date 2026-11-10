require "test_helper"
require "tmpdir"

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

  # CCS-425: an orientation fix swaps width and height; the size must follow the file, and a versioned address reads the same file
  test "reads the size again when the file is replaced, and ignores a version token" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      FileUtils.mkdir_p(root.join("digital-assets"))
      file = root.join("digital-assets/turn.png")
      FileUtils.cp(Rails.public_path.join("icon.png"), file)
      assert_equal [ 512, 512 ], ImageDimensions.for_path("/digital-assets/turn.png?v=1", root: root)

      portrait = [ 137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 10, 0, 0, 0, 20 ].pack("C*")
      File.binwrite(file, portrait)
      File.utime(Time.now + 60, Time.now + 60, file)
      assert_equal [ 10, 20 ], ImageDimensions.for_path("/digital-assets/turn.png", root: root)
    end
  end
end
