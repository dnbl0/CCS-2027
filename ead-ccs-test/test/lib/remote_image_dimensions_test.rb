require "test_helper"

# The size of a record's image held by the DAM (lib/remote_image_dimensions.rb): read from the start of the file, from the allowed
# image hosts only, and cached, so the IIIF manifest can give each canvas its size (CCS-57)
class RemoteImageDimensionsTest < ActiveSupport::TestCase
  DAM = "https://unimelbourne.widen.net/content/zof9bncptw/jpeg/UAC-1982_00221_PF.jpeg?w=2000&u=n4ezdx"
  JPEG = Rails.public_path.join("digital-assets/large/0000_013_1_pf.jpg").binread.byteslice(0, RemoteImageDimensions::RANGE + 1)
  PNG = Rails.public_path.join("icon.png").binread

  setup do
    @cache = ActiveSupport::Cache::MemoryStore.new
    @asked = []
  end

  def size(url, body: JPEG, hosts: %w[unimelbourne.widen.net])
    RemoteImageDimensions.for_url(url, hosts: hosts, cache: @cache, get: ->(uri) { @asked << uri.to_s; body })
  end

  test "reads a JPEG's or a PNG's size from the start of the file on an allowed host" do
    assert_equal [ 1279, 1600 ], size(DAM)
    assert_equal [ 512, 512 ], size("https://unimelbourne.widen.net/content/x/png/a.png", body: PNG)
  end

  test "asks once: the size is kept" do
    2.times { size(DAM) }
    assert_equal 1, @asked.size
    assert_equal [ 1279, 1600 ], RemoteImageDimensions.cached(DAM, cache: @cache)
  end

  test "asks nothing of a host that is not allowed, plain http, another port, or a link with a user in it" do
    [ "https://example.org/a.jpg", "http://unimelbourne.widen.net/a.jpg", "https://unimelbourne.widen.net:8443/a.jpg",
      "https://user@unimelbourne.widen.net/a.jpg", "/digital-assets/large/a.jpg", nil ].each { |url| assert_nil size(url) }
    assert_empty @asked
  end

  test "an answer that is not an image, or no answer, gives nil and is not kept" do
    assert_nil size(DAM, body: "<html>not an image</html>")
    assert_nil size(DAM, body: nil)
    assert_nil RemoteImageDimensions.cached(DAM, cache: @cache)
  end

  test "a failing request gives nil rather than an error" do
    failing = ->(_uri) { raise Net::OpenTimeout }
    assert_nil RemoteImageDimensions.for_url(DAM, hosts: %w[unimelbourne.widen.net], cache: @cache, get: failing)
  end
end
