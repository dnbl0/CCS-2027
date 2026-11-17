require "test_helper"
require_relative "../../support/colour_fakes"

# Colour::Fetcher asks only allowed places for images, and asks the DAM for a small PNG
class Colour::FetcherTest < ActiveSupport::TestCase
  include ColourFixtures

  LINK = "https://unimelbourne.widen.net/content/zwk4w4xvoa/jpeg/1973_0918_001-0041_PF.jpeg?w=720&quality=80&u=n4ezdx"

  def fetcher(answer = [ 200, "image/png", colour_fixture("red_blue.png") ])
    @asked = []
    Colour::Fetcher.new(get: ->(uri) { @asked << uri.to_s; answer }, public_root: Rails.root.join("test/fixtures/files/colour/public"))
  end

  test "a DAM link is asked for as a PNG 64 pixels wide, keeping its key" do
    assert Colour::Png.png?(fetcher.png(LINK))
    assert_equal [ "https://unimelbourne.widen.net/content/zwk4w4xvoa/png/1973_0918_001-0041_PF.png?w=64&u=n4ezdx" ], @asked
  end

  test "anything but an allowed host over https, or a local /digital-assets file, is refused without a request" do
    [ "http://unimelbourne.widen.net/content/a/jpeg/x.jpg", "https://unimelb-test.widen.net/content/a/jpeg/x.jpg",
      "https://example.com/content/a/jpeg/x.jpg", "https://user@unimelbourne.widen.net/content/a/jpeg/x.jpg",
      "https://unimelbourne.widen.net:8443/content/a/jpeg/x.jpg", "https://unimelbourne.widen.net/other/a.jpg",
      "file:///etc/passwd", "/digital-assets/../../../../config/master.key", "/etc/passwd", "" ].each do |path|
      assert_raises(Colour::Fetcher::Refused, path) { fetcher.png(path) }
    end
    assert_empty @asked
  end

  test "a failed or non-image answer is a failure" do
    assert_raises(Colour::Fetcher::Failed) { fetcher([ 404, "text/html", "" ]).png(LINK) }
    assert_raises(Colour::Fetcher::Failed) { fetcher([ 200, "text/html", "<html>" ]).png(LINK) }
  end

  test "this site's own /digital-assets files are read from public/, without a request" do
    assert Colour::Png.png?(fetcher.png("/digital-assets/thumbs/red_blue.png"))
    assert_empty @asked
    assert_raises(Colour::Fetcher::Failed) { fetcher.png("/digital-assets/thumbs/missing.png") }
  end

  test "a local JPEG is turned into a PNG by the libvips command line, or reported when it is not installed" do
    png = fetcher.png("/digital-assets/thumbs/brown.jpg")
    assert_equal %w[brown], Colour::Palette.new(Colour::Png.pixels(png)).names
  rescue Colour::Fetcher::Failed => e
    assert_match(/vipsthumbnail is not installed/, e.message)
  end

  test "the allowed hosts can be set (COLOUR_IMAGE_HOSTS)" do
    ENV["COLOUR_IMAGE_HOSTS"] = "unimelb-test.widen.net, unimelbourne.widen.net"
    assert_equal %w[unimelb-test.widen.net unimelbourne.widen.net], Colour::Fetcher.hosts
  ensure
    ENV.delete("COLOUR_IMAGE_HOSTS")
  end
end
