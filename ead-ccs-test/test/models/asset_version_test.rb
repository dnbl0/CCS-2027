require "test_helper"
require "tmpdir"

# CCS-425: a replaced image file shows without a manual purge. AssetVersion adds ?v=<token> to the address of a file this server
# holds under public/digital-assets; the token changes when the file does, so the address is new and no cache has it.
class AssetVersionTest < ActiveSupport::TestCase
  setup do
    @root = Pathname(Dir.mktmpdir)
    FileUtils.mkdir_p(@root.join("digital-assets/large"))
    @file = @root.join("digital-assets/large/a.jpg")
    File.binwrite(@file, "one")
    AssetVersion.reset!
  end

  teardown { FileUtils.remove_entry(@root) }

  def version(path, now: Time.now) = AssetVersion.url(path, root: @root, now: now)

  test "adds a token to a file held under /digital-assets" do
    assert_match %r{\A/digital-assets/large/a\.jpg\?v=\h+\z}, version("/digital-assets/large/a.jpg")
  end

  test "the token changes when the file is replaced, even with the same name and size" do
    before = version("/digital-assets/large/a.jpg")
    File.binwrite(@file, "two")
    File.utime(Time.now + 120, Time.now + 120, @file)

    assert_not_equal before, version("/digital-assets/large/a.jpg", now: Time.now + 300)
  end

  test "the token is the same while the file is the same" do
    assert_equal version("/digital-assets/large/a.jpg"), version("/digital-assets/large/a.jpg")
  end

  test "the file is looked at again only after a short while, not for every address on a page" do
    first = version("/digital-assets/large/a.jpg")
    File.utime(Time.now + 120, Time.now + 120, @file)

    assert_equal first, version("/digital-assets/large/a.jpg", now: Time.now + AssetVersion::CHECK_EVERY - 1)
    assert_not_equal first, version("/digital-assets/large/a.jpg", now: Time.now + AssetVersion::CHECK_EVERY + 1)
  end

  test "leaves alone what it cannot vouch for" do
    [ "/digital-assets/large/missing.jpg", "/icon.png", "https://example.org/digital-assets/a.jpg", "/digital-assets/../secret.jpg",
      "/digital-assets/large", "" ].each do |path|
      assert_equal path, version(path), path.inspect
    end
    assert_nil version(nil)
  end

  test "keeps a query string the address already has" do
    assert_match %r{\?x=1&v=\h+\z}, version("/digital-assets/large/a.jpg?x=1")
  end

  test "path strips the token again" do
    assert_equal "/digital-assets/large/a.jpg", AssetVersion.path("/digital-assets/large/a.jpg?v=1a2b")
    assert_equal "/digital-assets/large/a.jpg", AssetVersion.path("/digital-assets/large/a.jpg")
    assert_nil AssetVersion.path(nil)
  end

  test "versioned? recognises a token" do
    assert AssetVersion.versioned?("v=1a2b")
    assert AssetVersion.versioned?("x=1&v=ff")
    assert_not AssetVersion.versioned?("")
    assert_not AssetVersion.versioned?("v=")
    assert_not AssetVersion.versioned?(nil)
  end
end
