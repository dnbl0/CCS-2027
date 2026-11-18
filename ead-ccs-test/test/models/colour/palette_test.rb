require "test_helper"
require_relative "../../support/colour_fakes"

# Colour::Png reads the small PNGs the DAM sends; Colour::Palette finds the dominant colours and names them
class Colour::PaletteTest < ActiveSupport::TestCase
  include ColourFixtures

  test "the PNG reader reads RGB, palette and transparent images, and refuses what it cannot read" do
    assert_equal 256, Colour::Png.pixels(colour_fixture("red_blue.png")).size
    assert_equal [ [ 0xf4, 0xd3, 0x5e ] ], Colour::Png.pixels(colour_fixture("yellow_palette.png")).uniq
    assert_equal [ [ 0x7b, 0x2c, 0xbf ] ], Colour::Png.pixels(colour_fixture("purple_alpha.png")).uniq, "transparent pixels are left out"
    assert_raises(Colour::Png::Unsupported) { Colour::Png.pixels(colour_fixture("brown.jpg")) }
    assert_raises(Colour::Png::Unsupported) { Colour::Png.pixels(colour_fixture("red_blue.png").byteslice(0, 60)) }
  end

  test "an image's palette: its colours biggest first, as hex values, with their names" do
    palette = Colour::Palette.new(Colour::Png.pixels(colour_fixture("red_blue.png")))

    assert_equal %w[#d62828 #1d4ed8], palette.hexes
    assert_equal [ 0.625, 0.375 ], palette.swatches.map(&:share)
    assert_equal %w[red blue], palette.names
    assert_in_delta 1.0, palette.histogram.values.sum, 0.001
  end

  test "close shades are one colour, and a colour under a tenth of the image gets no name" do
    assert_equal %w[teal], Colour::Palette.new(Colour::Png.pixels(colour_fixture("teal_gradient.png"))).names
    pixels = ([ [ 250, 250, 250 ] ] * 92) + ([ [ 200, 20, 20 ] ] * 8)
    palette = Colour::Palette.new(pixels)
    assert_equal %w[white], palette.names
    assert_equal %w[#fafafa #c81414], palette.hexes
  end

  test "the twelve names" do
    { [ 200, 20, 30 ] => "red", [ 240, 140, 30 ] => "orange", [ 245, 210, 50 ] => "yellow", [ 40, 140, 70 ] => "green",
      [ 20, 140, 140 ] => "teal", [ 30, 90, 200 ] => "blue", [ 110, 60, 160 ] => "purple", [ 235, 130, 180 ] => "pink",
      [ 120, 75, 40 ] => "brown", [ 15, 15, 20 ] => "black", [ 130, 130, 130 ] => "grey", [ 252, 250, 245 ] => "white" }.each do |rgb, name|
      assert_equal name, Colour::Palette.name_for(rgb), rgb.inspect
    end
    assert_equal Colour::Palette::NAMES.sort, I18n.t("colours.names").keys.map(&:to_s).sort, "every name has its words"
  end
end
