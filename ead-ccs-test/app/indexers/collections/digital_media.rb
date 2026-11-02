require "yaml"

module Collections
  # Attaches audio, video and PDF files (config/digital_media.yml) to a document by accession number.
  # Each is stored as "kind|type|url|label" in digital_media_ssim (then "|captions|transcript" when the entry has those: the
  # URLs of a WebVTT captions file and a transcript, for audio and video); the format shows in the Format facet.
  class DigitalMedia
    CONFIG = "config/digital_media.yml".freeze
    FORMATS = { "audio" => "Audio", "video" => "Video", "pdf" => "PDF" }.freeze

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

    def attach(document)
      files = Array(document["accession_number_ssim"]).filter_map { |accession| @files_by_accession[accession] }.first
      return document if files.blank?

      formats = files.map { |f| FORMATS.fetch(f["kind"]) }
      document.merge(
        "digital_media_ssim" => files.map { |f| entry(f) },
        "has_digital_asset_bsi" => true,
        "digital_asset_format_ssim" => (Array(document["digital_asset_format_ssim"]) + formats).uniq
      )
    end
  end
end
