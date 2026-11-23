require "test_helper"
require "tmpdir"
require_relative "../support/pdf_fixture"

# CCS-36: the text inside PDFs (Collections::PdfText) and its place in the digital media attached to a record. The extraction tests
# use pdftotext and skip where it is not installed; the limit tests do not need it.
class PdfTextTest < ActiveSupport::TestCase
  setup { @dir = Dir.mktmpdir; @logger = Logger.new(@log = StringIO.new) }
  teardown { FileUtils.remove_entry(@dir); Collections::PdfText.reset!; ENV.delete("PDF_MEDIA_DIR"); ENV.delete("PDF_TEXT"); ENV.delete("PDF_TEXT_MAX_MB"); ENV.delete("PDF_TEXT_TIMEOUT"); ENV.delete("PDF_TEXT_MAX_CHARS") }

  def needs_pdftotext = (skip "needs pdftotext (Poppler)" unless Collections::PdfText.available?)

  test "the text of a PDF is read, tidied into one line" do
    needs_pdftotext
    path = PdfFixture.write(@dir, "a.pdf", "Violin made in Cremona (1700) with a paper label")

    assert_equal "Violin made in Cremona (1700) with a paper label", Collections::PdfText.extract(path, logger: @logger)
  end

  test "a file that is missing, not a PDF, or has no text gives nil and a log line, never an error" do
    needs_pdftotext
    File.write(File.join(@dir, "bad.pdf"), "not a pdf")
    empty = PdfFixture.write(@dir, "empty.pdf", "")

    assert_nil Collections::PdfText.extract(File.join(@dir, "none.pdf"), logger: @logger)
    assert_nil Collections::PdfText.extract(File.join(@dir, "bad.pdf"), logger: @logger)
    assert_nil Collections::PdfText.extract(empty, logger: @logger)
    assert_match(/file not found/, @log.string)
    assert_match(/pdftotext failed|no text layer/, @log.string)
  end

  test "a file over the size limit is not opened" do
    needs_pdftotext
    path = PdfFixture.write(@dir, "a.pdf", "Hello")
    File.truncate(path, 2 * 1024 * 1024)
    ENV["PDF_TEXT_MAX_MB"] = "1"

    assert_nil Collections::PdfText.extract(path, logger: @logger)
    assert_match(/larger than 1 MB/, @log.string)
  end

  test "the text kept is limited" do
    needs_pdftotext
    ENV["PDF_TEXT_MAX_CHARS"] = "10"

    assert_equal "Violin mad", Collections::PdfText.extract(PdfFixture.write(@dir, "a.pdf", "Violin made in Cremona"), logger: @logger)
  end

  test "a file that takes too long is stopped" do
    needs_pdftotext
    fake = File.join(@dir, "pdftotext")
    File.write(fake, "#!/bin/sh\nsleep 5\n")
    File.chmod(0o755, fake)
    ENV["PDF_TEXT_TIMEOUT"] = "1"
    original = ENV["PATH"]
    ENV["PATH"] = "#{@dir}:#{original}"
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    assert_nil Collections::PdfText.extract(PdfFixture.write(@dir, "a.pdf", "Hello"), logger: @logger)
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 4
    assert_match(/took more than 1 s/, @log.string)
  ensure
    ENV["PATH"] = original if original
  end

  # --- In the record ---

  def media(file = "a.pdf") = Collections::DigitalMedia.new("X.1" => [ { "kind" => "pdf", "file" => file, "type" => "application/pdf", "label" => "Catalogue" } ])

  test "a record with a PDF gains the text, in a field that is indexed and never stored or copied" do
    needs_pdftotext
    PdfFixture.write(@dir, "a.pdf", "Catalogue of violins")
    ENV["PDF_MEDIA_DIR"] = @dir

    document = media.attach("accession_number_ssim" => [ "X.1" ], "licence_type_ssim" => [ "Public domain - Copyright expired" ])

    assert_equal [ "Catalogue of violins" ], document["pdf_text_tim"]
    assert_equal [ "PDF" ], document["digital_asset_format_ssim"]
  end

  test "a withheld or sensitive record's PDF text is not indexed, so it cannot be found" do
    needs_pdftotext
    PdfFixture.write(@dir, "a.pdf", "Secret words")
    ENV["PDF_MEDIA_DIR"] = @dir

    withheld = media.attach("accession_number_ssim" => [ "X.1" ], "licence_type_ssim" => [ "ICIP Rights" ])
    sensitive = media.attach("accession_number_ssim" => [ "X.1" ], "restrictions_tsi" => "Culturally sensitive images")

    assert_not withheld.key?("pdf_text_tim")
    assert_not sensitive.key?("pdf_text_tim")
  end

  test "CCS-36: a PDF whose text cannot be read is named as not indexed, so the record page can say its text cannot be searched" do
    ENV["PDF_MEDIA_DIR"] = @dir
    document = media("missing.pdf").attach("accession_number_ssim" => [ "X.1" ], "licence_type_ssim" => [ "Public domain - Copyright expired" ])

    assert_not document.key?("pdf_text_tim")
    assert_equal 1, Array(document["pdf_text_unindexed_ssm"]).size
    assert_match(/missing\.pdf\z/, document["pdf_text_unindexed_ssm"].first)
  end

  test "PDF_TEXT=off, a missing file and a record with no PDF add nothing" do
    PdfFixture.write(@dir, "a.pdf", "Catalogue of violins")
    ENV["PDF_MEDIA_DIR"] = @dir
    ENV["PDF_TEXT"] = "off"
    assert_not media.attach("accession_number_ssim" => [ "X.1" ]).key?("pdf_text_tim")

    ENV.delete("PDF_TEXT")
    assert_not media("missing.pdf").attach("accession_number_ssim" => [ "X.1" ]).key?("pdf_text_tim")
    video = Collections::DigitalMedia.new("X.1" => [ { "kind" => "video", "file" => "a.mp4", "type" => "video/mp4", "label" => "Film" } ])
    assert_not video.attach("accession_number_ssim" => [ "X.1" ]).key?("pdf_text_tim")
  end
end
