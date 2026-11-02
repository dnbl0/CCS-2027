require "test_helper"
require "tmpdir"
require "open3"

class ZipWriterTest < ActiveSupport::TestCase
  def build
    io = StringIO.new
    ZipWriter.write(io) { |zip| yield zip }
    io.string
  end

  # The system unzip and Python's zipfile are the independent readers
  def with_zip(bytes)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "t.zip")
      File.binwrite(path, bytes)
      yield path
    end
  end

  def python_listing(path)
    script = "import sys,zipfile\nz=zipfile.ZipFile(sys.argv[1])\nassert z.testzip() is None\nprint(sorted((i.filename,z.read(i.filename)) for i in z.infolist()))"
    out, status = Open3.capture2("python3", "-I", "-c", script, path)
    assert status.success?, out
    out
  end

  test "an archive of data and file entries is read back intact by Python's zipfile" do
    Dir.mktmpdir do |dir|
      big = Random.new(1).bytes(3_000_000)
      File.binwrite(File.join(dir, "big.bin"), big)
      bytes = build do |zip|
        zip.add_data("manifest.csv", "a,b\n1,Māori\n")
        zip.add_file("emu-1/big.bin", File.join(dir, "big.bin"))
        zip.add_data("empty.txt", "")
      end

      with_zip(bytes) do |path|
        listing = python_listing(path)
        assert_includes listing, "'manifest.csv'"
        assert_includes listing, "emu-1/big.bin"
        script = "import sys,zipfile,hashlib\nz=zipfile.ZipFile(sys.argv[1])\nprint(hashlib.sha256(z.read('emu-1/big.bin')).hexdigest(), z.read('manifest.csv').decode('utf-8'), len(z.read('empty.txt')))"
        out, = Open3.capture2("python3", "-I", "-c", script, path)
        assert_includes out, Digest::SHA256.hexdigest(big)
        assert_includes out, "1,Māori"
      end
    end
  end

  test "unzip -t accepts it" do
    skip "unzip is not installed" unless system("which unzip > /dev/null 2>&1")

    with_zip(build { |zip| zip.add_data("a/b.txt", "hello") }) do |path|
      out, status = Open3.capture2e("unzip", "-t", path)
      assert status.success?, out
    end
  end

  test "names that could escape the folder are refused" do
    [ "../x", "a/../x", "/etc/passwd", "a//b", "a\\b", "C:/x", "", "a/", "./x", "x\u0000y", "x\ny" ].each do |name|
      assert_raises(ZipWriter::Error, name.inspect) { build { |zip| zip.add_data(name, "x") } }
    end
  end

  test "a name used twice is refused, ignoring case" do
    assert_raises(ZipWriter::Error) { build { |zip| zip.add_data("a.txt", "1"); zip.add_data("A.TXT", "2") } }
  end
end
