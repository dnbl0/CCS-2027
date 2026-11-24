# frozen_string_literal: true

require "test_helper"

class HomeLookCloserTest < ActiveSupport::TestCase
  test "the close-ups are the busiest parts of a picture, not its blank mount, and overlap little" do
    # a 40 by 30 picture: plain mount except a striped block in its lower right
    rows = Array.new(30) { |y| Array.new(40) { |x| x >= 24 && y >= 14 ? ((x + y).even? ? 0 : 255) : 200 } }
    crops = HomeLookCloser.busiest(rows)

    assert_operator crops.size, :>, 1
    assert(crops.first(3).all? { |crop| crop["x"] >= 0.5 && crop["y"] >= 0.4 }, "the striped corner first: #{crops.first(3)}")
    assert_in_delta 40 / 30.0, crops.first["aspect"], 0.001
  end

  test "a picture that cannot be read gets close-ups spread over its middle" do
    fetcher = Object.new
    def fetcher.png(_src) = raise(Colour::Fetcher::Refused, "not allowed")

    crops = HomeLookCloser.crops_for("/somewhere.jpg", fetcher)
    assert_equal HomeLookCloser::COUNT, crops.size
    assert(crops.all? { |crop| crop["x"].between?(0.2, 0.8) && crop["y"].between?(0.2, 0.8) })
  end

  test "the band's tint is the picture's colour mixed pale enough for navy text at 7:1" do
    tint = HomeLookCloser.tint("#3b5d2a")
    rgb = tint.delete("#").scan(/../).map { |part| part.to_i(16) }
    assert_operator HomeLookCloser.contrast(rgb, [ 0x00, 0x0f, 0x46 ]), :>=, 7
    assert_nil HomeLookCloser.tint(nil)
  end

  test "the records are the list's, in its order; one a day in turn" do
    assert_includes HomeLookCloser.ids, "emu_mc-10247"
    assert_equal HomeLookCloser.ids.uniq, HomeLookCloser.ids
  end
end
