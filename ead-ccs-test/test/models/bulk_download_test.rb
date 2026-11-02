require "test_helper"
require "tmpdir"
require "open3"
require "csv"

# CCS-167. The files are stand-ins in a temporary folder, standing for public/digital-assets.
class BulkDownloadTest < ActiveSupport::TestCase
  setup do
    @dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@dir, "large"))
    FileUtils.mkdir_p(File.join(@dir, "media"))
    { "large/a.jpg" => "A" * 10, "large/b.jpg" => "B" * 20, "media/film.mp4" => "F" * 30, "media/a.jpg" => "Z" * 5 }.each do |name, body|
      File.binwrite(File.join(@dir, name), body)
    end
  end

  teardown { FileUtils.remove_entry(@dir) }

  PUBLIC_DOMAIN = "Public domain - Copyright expired".freeze

  def doc(id, extra = {})
    SolrDocument.new({ "id" => id, "title_tsim" => [ "Title #{id}" ], "licence_type_ssim" => [ PUBLIC_DOMAIN ] }.merge(extra))
  end

  def plan(documents, **options) = BulkDownload.new(documents, asset_root: @dir, **options)

  def reasons(download) = download.skipped.map { |skip| [ skip.document&.id, skip.reason ] }

  test "an open record's large images and media files go in, in a folder named for the record" do
    download = plan([ doc("emu-1", "digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg", "/digital-assets/large/b.jpg" ],
                                    "digital_media_ssim" => [ "video|video/mp4|/digital-assets/media/film.mp4|Film" ]) ])

    assert_equal %w[emu-1/a.jpg emu-1/b.jpg emu-1/film.mp4], download.items.map(&:zip_name)
    assert_equal 60, download.total_bytes
    assert_empty download.skipped
    assert download.downloadable?
  end

  test "view-only and withheld records are skipped, each with its reason" do
    paths = { "digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg" ] }
    download = plan([ doc("emu-1", paths.merge("licence_type_ssim" => [ "Copyright - Current" ])),
                      doc("emu-2", paths.merge("licence_type_ssim" => [ "ICIP Rights" ])),
                      doc("emu-3", paths) ])

    assert_equal [ [ "emu-1", :not_downloadable ], [ "emu-2", :withheld ] ], reasons(download)
    assert_equal [ "emu-3/a.jpg" ], download.items.map(&:zip_name)
  end

  test "a sensitive record is skipped unless the visitor has chosen to view it" do
    sensitive = doc("emu-1", "restrictions_tsi" => "Sensitive", "digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg" ])

    assert_equal [ [ "emu-1", :sensitive ] ], reasons(plan([ sensitive ]))
    assert_empty plan([ sensitive ], may_view_sensitive: ->(document) { document.id == "emu-1" }).skipped
  end

  test "a record with no assets, a missing file, an unknown record and a file elsewhere are each skipped" do
    download = plan([ doc("emu-1"),
                      doc("emu-2", "digital_asset_large_paths_ssim" => [ "/digital-assets/large/gone.jpg", "/digital-assets/large/a.jpg" ]),
                      nil,
                      doc("emu-4", "digital_asset_large_paths_ssim" => [ "https://elsewhere.example/x.jpg", "/other/a.jpg" ]) ])

    assert_equal [ [ "emu-1", :no_assets ], [ "emu-2", :file_missing ], [ nil, :not_found ], [ "emu-4", :file_missing ], [ "emu-4", :file_missing ] ],
                 reasons(download)
    assert_equal "gone.jpg", download.skipped[1].name
    assert_equal [ "emu-2/a.jpg" ], download.items.map(&:zip_name)
  end

  test "paths that climb out of the asset folder or follow a link out of it are never zipped" do
    outside = Dir.mktmpdir
    File.write(File.join(outside, "secret.txt"), "secret")
    File.symlink(File.join(outside, "secret.txt"), File.join(@dir, "large", "link.jpg"))
    File.symlink(outside, File.join(@dir, "linkdir"))
    hostile = [ "/digital-assets/../secret.txt", "/digital-assets/large/../../secret.txt", "/digital-assets/%2e%2e/%2e%2e/etc/passwd",
                "/digital-assets/large/link.jpg", "/digital-assets/linkdir/secret.txt", "/digital-assets/large/a.jpg%00.jpg",
                "/digital-assets/large", "/digital-assets/", "/etc/passwd" ]
    download = plan([ doc("emu-1", "digital_asset_large_paths_ssim" => hostile) ])

    assert_empty download.items
    assert_equal [ :file_missing ] * hostile.size, download.skipped.map(&:reason)
  ensure
    FileUtils.remove_entry(outside) if outside
  end

  test "the same file name twice in a record is kept, as a-2.jpg" do
    download = plan([ doc("emu-1", "digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg", "/digital-assets/media/a.jpg" ]) ])

    assert_equal %w[emu-1/a.jpg emu-1/a-2.jpg], download.items.map(&:zip_name)
  end

  test "a record id with odd characters makes a safe folder name" do
    download = plan([ doc("../we ird/id", "digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg" ]) ])

    assert_equal [ "__we_ird_id/a.jpg" ], download.items.map(&:zip_name)
  end

  test "over the file or size limit the download is refused as a whole, with the reason" do
    many = doc("emu-1", "digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg" ])
    download = plan([ many ])
    assert_nil download.limit_problem

    stub_const(BulkDownload, :MAX_FILES, 1) do
      assert_nil plan([ many ]).limit_problem
      assert_equal :too_many_files, plan([ many, doc("emu-2", "digital_asset_large_paths_ssim" => [ "/digital-assets/large/b.jpg" ]) ]).limit_problem
    end
    stub_const(BulkDownload, :MAX_BYTES, 5) do
      too_big = plan([ many ])
      assert_equal :too_large, too_big.limit_problem
      assert_not too_big.downloadable?
      assert_raises(ArgumentError) { too_big.write_zip(StringIO.new, persistent_link: ->(_) { "x" }) }
    end
  end

  test "the zip holds the files and a manifest of essential information, and Python reads it" do
    documents = [ doc("emu-1", "title_tsim" => [ "=Evil title" ], "rights_ssim" => [ "Public domain" ], "credit_line_tsim" => [ "Gift of X" ],
                            "digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg" ],
                            "digital_media_ssim" => [ "video|video/mp4|/digital-assets/media/film.mp4|Film" ]) ]
    io = StringIO.new
    plan(documents).write_zip(io, persistent_link: ->(document) { "https://ccs.example/catalog/#{document.id}" })

    script = "import sys,zipfile\nz=zipfile.ZipFile(sys.argv[1])\nassert z.testzip() is None\nprint(sorted(z.namelist()))\nprint(z.read('emu-1/film.mp4').decode())\nprint(z.read('manifest.csv').decode('utf-8-sig'))"
    out = Dir.mktmpdir do |dir|
      path = File.join(dir, "t.zip")
      File.binwrite(path, io.string)
      Open3.capture2("python3", "-I", "-c", script, path).first
    end

    assert_includes out, "['emu-1/a.jpg', 'emu-1/film.mp4', 'manifest.csv']"
    assert_includes out, "F" * 30
    manifest = CSV.parse(out[out.index("Record ID")..])
    assert_equal [ "Record ID", "Title", "File in this zip", "Licence", "Copyright", "Credit line", "Persistent link" ], manifest.first
    assert_equal [ "emu-1", "'=Evil title", "emu-1/a.jpg", PUBLIC_DOMAIN, "Public domain", "Gift of X", "https://ccs.example/catalog/emu-1" ], manifest[1]
  end

  test "the file name carries the date" do
    assert_equal "ccs-assets-20261102.zip", BulkDownload.filename(Time.zone.local(2026, 11, 2, 10))
  end

  private

  def stub_const(mod, name, value)
    original = mod.const_get(name)
    mod.send(:remove_const, name)
    mod.const_set(name, value)
    yield
  ensure
    mod.send(:remove_const, name)
    mod.const_set(name, original)
  end
end
