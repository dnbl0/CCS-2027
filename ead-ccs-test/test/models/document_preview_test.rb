require "test_helper"

# CCS-164: Office and OpenOffice files are documents, with a PDF preview LibreOffice makes when they are indexed
class DocumentPreviewTest < ActiveSupport::TestCase
  test "Office, OpenOffice and eBook files are known kinds" do
    { "report.docx" => :document, "sheet.xlsx" => :document, "slides.pptx" => :document, "notes.odt" => :document,
      "data.ods" => :document, "talk.odp" => :document, "old.doc" => :document, "book.epub" => :ebook, "skull.glb" => :model_3d }.each do |name, kind|
      assert_equal kind, MediaTypes.for(filename: name).kind, name
    end
    assert_equal :document, MediaTypes.for(mime: "application/vnd.openxmlformats-officedocument.wordprocessingml.document").kind
    assert_equal "media_viewers/document", MediaTypes.viewer_for(:document)
  end

  test "a glTF or GLB model and an EPUB have their viewers; a 3D format model-viewer cannot show says it cannot be previewed" do
    assert_equal "media_viewers/model", MediaTypes.viewer_for_item({ kind: "model_3d", type: "model/gltf-binary", url: "/m/egg.glb?v=1" })
    assert_equal "media_viewers/model", MediaTypes.viewer_for_item({ kind: "model_3d", type: "application/octet-stream", url: "/m/egg.gltf" })
    assert_equal MediaTypes::UNSUPPORTED_VIEWER, MediaTypes.viewer_for_item({ kind: "model_3d", type: "model/stl", url: "/m/egg.stl" })
    assert_equal "media_viewers/ebook", MediaTypes.viewer_for_item({ kind: "ebook", type: "application/epub+zip", url: "/b/notes.epub" })
  end

  test "a preview's address is the file's name and a digest of its address, under the previews folder" do
    path = DocumentPreview.public_path("/digital-assets/media/Annual%20Report.docx")
    assert_match(%r{\A/digital-assets/previews/annual-report-\h{10}\.pdf\z}, path)
    assert_not_equal path, DocumentPreview.public_path("/elsewhere/Annual%20Report.docx")
  end

  test "LibreOffice turns a document into a PDF preview, once" do
    skip "LibreOffice (soffice) is not installed" unless DocumentPreview.available?
    Dir.mktmpdir do |dir|
      source = File.join(dir, "letter.rtf")
      File.write(source, '{\rtf1\ansi Dear Professor, the specimens arrived safely.}')
      url = "/digital-assets/media/test-#{SecureRandom.hex(4)}/letter.rtf"
      preview = DocumentPreview.convert(source, url)

      assert_equal DocumentPreview.public_path(url), preview
      assert DocumentPreview.file_for(url).file?
      assert_equal "%PDF", File.binread(DocumentPreview.file_for(url), 4)
    ensure
      FileUtils.rm_f(DocumentPreview.file_for(url)) if url
    end
  end
end
