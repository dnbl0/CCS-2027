require "test_helper"
require "tmpdir"

# CCS-71: the production stylesheet is one file, and text assets have a gzipped copy to serve (lib/asset_bundle.rb)
class AssetBundleTest < ActiveSupport::TestCase
  def in_assets
    Dir.mktmpdir do |dir|
      Dir.mkdir(File.join(dir, "components"))
      yield dir
    end
  end

  test "flatten puts each imported file where its @import was, in order, and imports of imports too" do
    in_assets do |dir|
      File.write(File.join(dir, "a-1.css"), "a { color: red }\n")
      File.write(File.join(dir, "components/b-2.css"), %(@import url("/assets/c-3.css");\nb { color: blue }\n))
      File.write(File.join(dir, "c-3.css"), "c { color: green }\n")
      manifest = %(/* manifest */\n@import url("/assets/a-1.css");\n@import url("/assets/components/b-2.css");\nz { color: black }\n)

      flat = AssetBundle.flatten(manifest, dir)

      assert_equal [ "a { color: red }", "c { color: green }", "b { color: blue }", "z { color: black }" ], flat.lines.map(&:strip).reject { |line| line.empty? || line.start_with?("/*") }
      assert_no_match(/@import/, flat)
    end
  end

  test "an import that is not a file, and a repeat of one already in place, are handled" do
    in_assets do |dir|
      File.write(File.join(dir, "a-1.css"), "a { color: red }\n")
      css = %(@import url("/assets/a-1.css");\n@import url("/assets/a-1.css");\n@import url("/assets/missing-9.css");\n@import url("https://example.org/x.css");\n)

      flat = AssetBundle.flatten(css, dir)

      assert_equal 1, flat.scan("a { color: red }").size
      assert_includes flat, %(@import url("/assets/missing-9.css");) # left for the browser to report, not lost
      assert_includes flat, %(@import url("https://example.org/x.css");)
    end
  end

  test "flatten_css rewrites only the stylesheets that import, and gzip_assets writes smaller copies of large text files" do
    in_assets do |dir|
      File.write(File.join(dir, "a-1.css"), "a { color: red }\n" * 200)
      File.write(File.join(dir, "app-2.css"), %(@import url("/assets/a-1.css");\n))
      File.write(File.join(dir, "logo-3.png"), "x" * 5000)
      File.write(File.join(dir, "tiny-4.css"), "a{}")

      assert_equal [ File.join(dir, "app-2.css") ], AssetBundle.flatten_css(dir)
      zipped = AssetBundle.gzip_assets(dir).map { |file| File.basename(file) }.sort

      assert_equal %w[a-1.css.gz app-2.css.gz], zipped
      assert_equal File.read(File.join(dir, "app-2.css")), Zlib.gunzip(File.binread(File.join(dir, "app-2.css.gz")))
    end
  end

  test "the precompile task runs it, so the container's build produces the bundle" do
    rake = Rails.root.join("lib/tasks/asset_bundle.rake").read

    assert_match(/task "assets:precompile" do\s+AssetBundle\.run\(/, rake)
  end
end
