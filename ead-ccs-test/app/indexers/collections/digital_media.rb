require "yaml"

module Collections
  # Attaches audio, video, PDF and (CCS-164) Office, OpenOffice, eBook and 3D files (config/digital_media.yml) to a document by
  # accession number.
  # Each is stored as "kind|type|url|label" in digital_media_ssim (then "|captions|transcript" when the entry has those: the
  # URLs of a WebVTT captions file and a transcript, for audio and video); the format shows in the Format facet.
  class DigitalMedia
    CONFIG = "config/digital_media.yml".freeze
    FORMATS = { "audio" => "Audio", "video" => "Video", "pdf" => "PDF", "document" => "Document", "ebook" => "eBook", "model_3d" => "3D model" }.freeze

    def self.default
      @default ||= new(YAML.safe_load_file(Rails.root.join(CONFIG)) || {})
    end

    def self.base_url
      ENV.fetch("CCS_MEDIA_BASE_URL", "/digital-assets/media").chomp("/")
    end

    # -> { kind:, type:, url:, label:, captions:, transcript: } (the last two nil when the entry has none)
    def self.parse(entry)
      kind, type, url, label, captions, transcript = entry.split("|", 6)
      { kind: kind, type: type, url: url, label: label, captions: captions.presence, transcript: transcript.presence }
    end

    def initialize(files_by_accession)
      @files_by_accession = files_by_accession
    end

    def entry(file)
      parts = [ file["kind"], file["type"], "#{self.class.base_url}/#{ERB::Util.url_encode(file["file"])}", file["label"] ]
      parts += [ file["captions"], file["transcript"] ].map { |name| name && "#{self.class.base_url}/#{ERB::Util.url_encode(name)}" } if file["captions"] || file["transcript"]
      parts.join("|")
    end
    private :entry

    # PDF_TEXT=off stops the text of PDFs being read at indexing (CCS-36); PDF_MEDIA_DIR is where the PDF files are on this machine
    def self.pdf_text? = ENV["PDF_TEXT"].to_s.downcase != "off"

    def self.pdf_dir = Pathname.new(ENV.fetch("PDF_MEDIA_DIR") { Rails.root.join("public/digital-assets/media").to_s })

    def pdf_text?(files) = self.class.pdf_text? && files.any? { |file| file["kind"] == "pdf" }
    private :pdf_text?

    # The text of the record's PDFs ([file, text or nil] each). None for a record whose assets are withheld or sensitive
    # (AccessPolicy, Sensitivity): its PDF is not searchable, as it is not shown. A file that cannot be read gives nil: it is then
    # named in pdf_text_unindexed_ssm, so the record page can say its text cannot be searched (CCS-36 "Not indexed").
    def pdf_text(document, files)
      return [] if RobotsPolicy.withheld?(SolrDocument.new(document))

      files.select { |file| file["kind"] == "pdf" }.map { |file| [ file, PdfText.extract(self.class.pdf_dir.join(file["file"].to_s)) ] }
    end
    private :pdf_text

    # CCS-164: an Office or OpenOffice file gets a PDF preview (DocumentPreview), and the preview's text joins the full-text search
    # as a PDF's does (CCS-36). Not for a withheld or sensitive record, whose files are not shown.
    def document_previews(document, files)
      documents = files.select { |file| file["kind"] == "document" }
      return [] if documents.empty? || !DocumentPreview.enabled? || RobotsPolicy.withheld?(SolrDocument.new(document))

      documents.filter_map do |file|
        url = "#{self.class.base_url}/#{ERB::Util.url_encode(file["file"])}"
        preview = DocumentPreview.convert(self.class.pdf_dir.join(file["file"].to_s), url)
        [ file.merge("file" => nil), PdfText.extract(DocumentPreview.file_for(url)) ] if preview && self.class.pdf_text?
      end
    end
    private :document_previews

    def attach(document)
      files = Array(document["accession_number_ssim"]).filter_map { |accession| @files_by_accession[accession] }.first
      return document if files.blank?

      formats = files.filter_map { |f| FORMATS[f["kind"]] }
      extracted = pdf_text?(files) ? pdf_text(document, files) : []
      extracted += document_previews(document, files)
      texts = extracted.filter_map(&:last)
      unindexed = extracted.select { |file, text| text.nil? && file["file"] }.map { |file, _text| "#{self.class.base_url}/#{ERB::Util.url_encode(file["file"])}" }
      document = document.merge("pdf_text_tim" => texts) if texts.any?
      document = document.merge("pdf_text_unindexed_ssm" => unindexed) if unindexed.any?
      document.merge(
        "digital_media_ssim" => files.map { |f| entry(f) },
        "has_digital_asset_bsi" => true,
        "digital_asset_format_ssim" => (Array(document["digital_asset_format_ssim"]) + formats).uniq
      )
    end
  end
end
