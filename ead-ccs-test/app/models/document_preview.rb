# frozen_string_literal: true

require "open3"
require "tmpdir"
require "timeout"

# A PDF preview of an Office or OpenOffice file (CCS-164: Word, Excel, PowerPoint and their OpenDocument cousins), made when the file
# is indexed by LibreOffice's converter (soffice --headless --convert-to pdf) and kept in public/digital-assets/previews, so the record
# page can show the document without any outside service or new script. The preview's text also goes to the full-text search
# (CCS-36). No LibreOffice, a file it cannot read, or a conversion over the time limit gives no preview: the page then offers the file
# itself (where it may be downloaded). DOCUMENT_PREVIEWS=off stops conversion; DOCUMENT_PREVIEW_TIMEOUT (seconds, 60) limits it.
module DocumentPreview
  COMMAND = "soffice".freeze
  PUBLIC_DIR = "digital-assets/previews".freeze

  module_function

  def enabled? = ENV["DOCUMENT_PREVIEWS"].to_s.downcase != "off"

  def available?
    @available = system(COMMAND, "--version", out: File::NULL, err: File::NULL) ? true : false if @available.nil?
    @available
  end

  def reset! = @available = nil

  # The preview's public path for a file's address (its name and a short digest of the address, so two files of one name differ)
  def public_path(source_url)
    path = URI.parse(source_url.to_s).path.to_s
    name = File.basename(CGI.unescape(path), ".*").parameterize.presence || "document"
    "/#{PUBLIC_DIR}/#{name}-#{Digest::SHA256.hexdigest(path)[0, 10]}.pdf"
  rescue URI::InvalidURIError
    nil
  end

  def file_for(source_url) = (path = public_path(source_url)) && Rails.public_path.join(path.delete_prefix("/"))

  # The preview's address when it has been made, else nil
  def url_for(source_url)
    file = file_for(source_url)
    public_path(source_url) if file&.file?
  end

  # Makes the preview of the file at file_path (the original of source_url) unless it is there already and newer; its address, or nil
  def convert(file_path, source_url, logger: Rails.logger)
    file_path = Pathname.new(file_path.to_s)
    target = file_for(source_url)
    return nil unless enabled? && target && file_path.file?
    return public_path(source_url) if target.file? && target.mtime >= file_path.mtime
    return skip(logger, file_path, "LibreOffice (soffice) is not installed") unless available?

    Dir.mktmpdir("ccs-preview") do |dir|
      out, status = run([ COMMAND, "--headless", "--norestore", "--convert-to", "pdf", "--outdir", dir, file_path.to_s ])
      made = Pathname.new(dir).join("#{file_path.basename('.*')}.pdf")
      return skip(logger, file_path, "conversion failed: #{out.to_s.lines.last.to_s.strip}") unless status&.success? && made.file?

      FileUtils.mkdir_p(target.dirname)
      FileUtils.mv(made, target)
    end
    public_path(source_url)
  rescue Timeout::Error
    skip(logger, file_path, "took more than #{timeout_seconds} s")
  end

  def run(command)
    Timeout.timeout(timeout_seconds) { Open3.capture2e(*command) }
  end
  private_class_method :run

  def timeout_seconds = Integer(ENV.fetch("DOCUMENT_PREVIEW_TIMEOUT", "60"), exception: false) || 60

  def skip(logger, path, reason)
    logger.warn("Document preview skipped for #{File.basename(path.to_s)}: #{reason}")
    nil
  end
end
