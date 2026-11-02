require "test_helper"
require "open3"

# CCS-167: choosing records on the saved records page or a list, reviewing, then one zip of the downloadable files.
# Real records from the dev index, with the real files in public/digital-assets.
class BulkDownloadsTest < ActionDispatch::IntegrationTest
  OPEN = "emu-9044"          # Public domain - Copyright expired, with several images
  OPEN_TWO = "emu-406126"    # Public domain, one image
  VIEW_ONLY = "emu-20335"    # Copyright - Current
  NO_ASSETS_NEEDED = "no-such-record"

  def save(*ids) = ids.each { |id| put "/bookmarks/#{id}", xhr: true, headers: { "Accept" => "application/json" } }

  def zip_names(body)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "t.zip")
      File.binwrite(path, body)
      script = "import sys,zipfile\nz=zipfile.ZipFile(sys.argv[1])\nassert z.testzip() is None\nprint('\\n'.join(z.namelist()))"
      Open3.capture2("python3", "-I", "-c", script, path).first.split("\n")
    end
  end

  test "the saved records page offers the records that have assets as a group of checkboxes, saying which can be downloaded" do
    save(OPEN, VIEW_ONLY)
    get "/bookmarks"

    assert_select "details.bulk-select summary", text: "Download digital assets"
    assert_select "form[action='/downloads/review'][method=post] fieldset legend", text: "Choose the records to download"
    assert_select "input[type=checkbox][name='ids[]'][value='#{OPEN}']"
    assert_select "input[type=checkbox][name='ids[]'][value='#{VIEW_ONLY}']"
    assert_select ".bulk-select__status", text: /Can be downloaded: \d+ files?/
    assert_select ".bulk-select__status", text: "Cannot be downloaded: view only"
    assert_select "label[for=bulk-select-0]"
  end

  test "a list page offers the same choice" do
    save(OPEN)
    list = List.create!(name: "Mine", user: User.last)
    list.list_items.create!(document_id: OPEN)
    get "/lists/#{list.id}"

    assert_select "form[action='/downloads/review'] input[name='ids[]'][value='#{OPEN}']"
    assert_select "input[name=return_to][value='/lists/#{list.id}']", visible: :all
  end

  test "review says what goes in and what is left out, and why" do
    post "/downloads/review", params: { ids: [ OPEN, VIEW_ONLY, NO_ASSETS_NEEDED ], return_to: "/bookmarks" }

    assert_response :success
    assert_select "h2", text: /1 record will be downloaded/
    assert_select "li", text: /view only|can be viewed but not downloaded/i
    assert_select "li", text: /no longer in the collection/
    assert_select "input[type=submit][value^='Download zip file (']"
    assert_select "input[name='ids[]'][value='#{OPEN}']", visible: :all
    assert_select "input[name='ids[]'][value='#{VIEW_ONLY}']", count: 0
  end

  test "the zip holds only the open record's files and a manifest" do
    post "/downloads", params: { ids: [ OPEN, OPEN_TWO, VIEW_ONLY ] }

    assert_response :success
    assert_equal "application/zip", response.media_type
    assert_match(/attachment; filename="ccs-assets-\d{8}\.zip"/, response.headers["Content-Disposition"])
    names = zip_names(response.body)
    assert_includes names, "manifest.csv"
    assert names.any? { |name| name.start_with?("#{OPEN}/") }
    assert names.any? { |name| name.start_with?("#{OPEN_TWO}/") }
    assert names.none? { |name| name.start_with?("#{VIEW_ONLY}/") }
  end

  test "with nothing downloadable there is no zip: back to the page with a message" do
    post "/downloads", params: { ids: [ VIEW_ONLY ], return_to: "/bookmarks" }

    assert_redirected_to "/bookmarks"
    follow_redirect!
    assert_select "[role=alert], .alert", text: /None of the chosen records has a file that can be downloaded/
  end

  test "no records chosen, and too many chosen, go back with a message" do
    post "/downloads/review", params: { return_to: "/bookmarks" }
    assert_redirected_to "/bookmarks"
    follow_redirect!
    assert_select ".alert", text: /Choose at least one record/

    post "/downloads/review", params: { ids: (1..BulkDownload::MAX_RECORDS + 1).map { |n| "emu-#{n}" }, return_to: "/bookmarks" }
    follow_redirect!
    assert_select ".alert", text: /Choose at most #{BulkDownload::MAX_RECORDS} records/
  end

  test "a selection over the file limit is refused with the limit stated, and offers no download" do
    original = BulkDownload::MAX_FILES
    BulkDownload.send(:remove_const, :MAX_FILES)
    BulkDownload.const_set(:MAX_FILES, 1)
    post "/downloads/review", params: { ids: [ OPEN, OPEN_TWO ] }

    assert_select ".alert", text: /more than 1 files/
    assert_select "input[type=submit][value^='Download zip']", count: 0
    post "/downloads", params: { ids: [ OPEN, OPEN_TWO ] }
    assert_response :redirect
  ensure
    BulkDownload.send(:remove_const, :MAX_FILES)
    BulkDownload.const_set(:MAX_FILES, original)
  end

  test "return_to is only ever one of the selecting pages" do
    post "/downloads/review", params: { ids: [ OPEN ], return_to: "https://evil.example/" }
    assert_select "a.btn[href='/bookmarks']", text: "Back"

    post "/downloads/review", params: { ids: [ OPEN ], return_to: "/lists/7" }
    assert_select "a.btn[href='/lists/7']", text: "Back"
  end
end
