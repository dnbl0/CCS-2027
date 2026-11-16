require "open3"
require "timeout"

module Collections
  # The text inside a PDF (CCS-36), for the "Full text" search. It runs pdftotext (Poppler) on the file, with a size limit, a time
  # limit and a limit on the text kept, and gives nil rather than fail: an indexing run must never stop for one bad file.
  # OCR is out of scope: a scanned PDF with no text layer gives no text (nil), and is simply not found by Full text.
  # Settings (environment): PDF_TEXT_MAX_MB (50), PDF_TEXT_TIMEOUT seconds (30), PDF_TEXT_MAX_CHARS (1,000,000).
  module PdfText
    COMMAND = "pdftotext".freeze
    CONTROL = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/

    module_function

    def available?
      @available = system(COMMAND, "-v", out: File::NULL, err: File::NULL) ? true : false if @available.nil?
      @available
    end

    def reset! = @available = nil

    # The text, or nil (no file, too big, no text layer, a failure or timeout; the reason is logged)
    def extract(path, logger: Rails.logger)
      path = path.to_s
      return skip(logger, path, "file not found") unless File.file?(path)
      return skip(logger, path, "pdftotext is not installed") unless available?

      limit = max_mb * 1024 * 1024
      return skip(logger, path, "larger than #{max_mb} MB") if File.size(path) > limit

      text = run(path, logger)
      text = text&.gsub(CONTROL, " ")&.gsub(/\s+/, " ")&.strip
      return skip(logger, path, "no text layer (scanned? OCR is not done)") if text.blank?

      text.length > max_chars ? text[0, max_chars] : text
    end

    def run(path, logger)
      Open3.popen3(COMMAND, "-q", "-enc", "UTF-8", "-nopgbrk", File.expand_path(path), "-") do |stdin, stdout, stderr, thread|
        stdin.close
        reader = Thread.new { stdout.read }
        begin
          Timeout.timeout(timeout_seconds) { thread.join }
        rescue Timeout::Error
          Process.kill("KILL", thread.pid) rescue nil # rubocop:disable Style/RescueModifier -- already gone is fine
          reader.kill
          return skip(logger, path, "took more than #{timeout_seconds} s")
        end
        return skip(logger, path, "pdftotext failed: #{stderr.read.to_s.strip.lines.first}") unless thread.value.success?

        reader.value.to_s.dup.force_encoding("UTF-8").scrub
      end
    rescue SystemCallError => e
      skip(logger, path, e.class.to_s)
    end
    private_class_method :run

    def skip(logger, path, reason)
      logger.warn("PDF text skipped for #{File.basename(path)}: #{reason}")
      nil
    end
    private_class_method :skip

    def max_mb = positive(ENV.fetch("PDF_TEXT_MAX_MB", 50), 50)
    def timeout_seconds = positive(ENV.fetch("PDF_TEXT_TIMEOUT", 30), 30)
    def max_chars = positive(ENV.fetch("PDF_TEXT_MAX_CHARS", 1_000_000), 1_000_000)
    def positive(value, default) = (Integer(value, exception: false) || 0).positive? ? Integer(value) : default
    private_class_method :max_mb, :timeout_seconds, :max_chars, :positive
  end
end
