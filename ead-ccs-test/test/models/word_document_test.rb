require "test_helper"
require "open3"

# CCS-137: the citations' Word download, built with no extra library
class WordDocumentTest < ActiveSupport::TestCase
  def citations
    [ [ [ "Grainger, P. A. (1922). ", false ], [ "Ukulele & case <boxed>", true ], [ " [ukulele]. Grainger Museum Collection.", false ] ],
      [ [ "Smith, J. (n.d.). ", false ], [ "Shell", true ], [ ".", false ] ] ]
  end

  def docx = WordDocument.new(heading: "References", paragraphs: citations).to_s

  test "Citation marks the title as italic in every style, and its plain text has no marks" do
    source = Citation::Source.new(title: "Ukulele", creators: [ Citation.parse_name("Grainger, Percy Aldridge") ], year: "1922",
                                  object_type: "ukulele", collection: "Grainger Museum Collection", accession: "00.0001",
                                  uom_id: nil, url: "https://example.test/catalog/emu-1")
    Citation::STYLES.each do |style|
      runs = Citation.reference_runs([ source ], style, accessed: Date.new(2026, 11, 23)).first
      assert_includes runs, [ "Ukulele", true ], style
      assert_equal runs.map(&:first).join, Citation.format(source, style, accessed: Date.new(2026, 11, 23)), style
      assert_no_match(/[\u{E000}\u{E001}]/, Citation.format(source, style, accessed: Date.new(2026, 11, 23)))
    end
    assert_equal "Works Cited", Citation.list_heading(:mla)
  end

  test "the file is a zip of the three parts a Word document needs, the title runs italic and the text escaped" do
    skip "unzip is not installed" unless system("which unzip", out: File::NULL)
    file = Tempfile.new([ "citations", ".docx" ]).tap { |f| f.binmode; f.write(docx); f.flush }
    listing, status = Open3.capture2e("unzip", "-l", file.path)
    assert status.success?, listing
    %w[[Content_Types].xml _rels/.rels word/document.xml].each { |part| assert_includes listing, part }

    body, = Open3.capture2e("unzip", "-p", file.path, "word/document.xml")
    assert_includes body, "<w:i/>"
    assert_includes body, "Ukulele &amp; case &lt;boxed&gt;"
    assert_includes body, %(<w:ind w:left="720" w:hanging="720"/>) # a reference list's hanging indent
  ensure
    file&.close!
  end

  test "LibreOffice reads it as a document with the citations' text" do
    skip "LibreOffice (soffice) is not installed" unless DocumentPreview.available?
    Dir.mktmpdir do |dir|
      path = File.join(dir, "citations.docx")
      File.binwrite(path, docx)
      out, status = Open3.capture2e("soffice", "--headless", "--norestore", "--convert-to", "txt:Text", "--outdir", dir, path)
      assert status.success?, out
      text = File.read(File.join(dir, "citations.txt"))
      assert_includes text, "References"
      assert_includes text, "Grainger, P. A. (1922). Ukulele & case <boxed> [ukulele]."
    end
  end
end
