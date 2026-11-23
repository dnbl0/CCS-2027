# frozen_string_literal: true

# The kinds of file a record's media can be, and the viewer each one has (CCS-57). This is the ONE place that maps a file's
# format to how the record page shows it: add a viewer by adding a partial under app/views/media_viewers/ and naming it in
# VIEWERS. A kind without a viewer (3D models, other files) gets the "cannot be previewed" partial, which still shows the
# file's name and metadata, so nothing silently disappears.
#
#   kind        viewer                              notes
#   :image      media_viewers/_image                OpenSeadragon deep zoom (DeepZoomComponent); IIIF tiles when the record carries them
#   :video      media_viewers/_video                the browser's own player; captions from the record's captions file
#   :audio      media_viewers/_audio                as video; a transcript link when the record has one
#   :pdf        media_viewers/_pdf                  opens in a new tab (no in-page viewer: it would be a new dependency)
#   :document   media_viewers/document              Office and OpenOffice files (CCS-164): a PDF preview made by LibreOffice when the
#                                                   file is indexed (DocumentPreview), and the original to download where allowed
#   :ebook      media_viewers/ebook                 EPUB (CCS-164): read a page at a time in the page by epub.js (vendored)
#   :model_3d   media_viewers/model                 glTF and GLB (CCS-164): Google model-viewer (vendored). Other 3D formats (OBJ, STL,
#                                                   USDZ, FBX, PLY) it cannot show get the "cannot be previewed" partial
#   :other      none                                anything the DAM holds that a browser cannot show
module MediaTypes
  Type = Data.define(:kind, :label, :viewer) do
    def previewable? = viewer.present?
  end

  UNSUPPORTED_VIEWER = "media_viewers/unsupported"

  VIEWERS = {
    image: "media_viewers/image",
    video: "media_viewers/video",
    audio: "media_viewers/audio",
    pdf: "media_viewers/pdf",
    document: "media_viewers/document",
    ebook: "media_viewers/ebook",
    model_3d: "media_viewers/model"
  }.freeze

  # The 3D formats model-viewer shows; a model in any other format gets UNSUPPORTED_VIEWER
  VIEWABLE_MODEL_EXTENSIONS = %w[glb gltf].freeze
  VIEWABLE_MODEL_TYPES = %w[model/gltf-binary model/gltf+json].freeze

  LABELS = { image: "Image", video: "Video", audio: "Audio", pdf: "PDF document", document: "Document", ebook: "eBook", model_3d: "3D model",
             other: "File" }.freeze

  # What the DAM calls a file's format (file_properties.format_type in the ingest's assets_json, and format_types_ssim in the
  # index once it carries it), lower case. Anything not listed is looked up by MIME type, then file extension.
  FORMAT_TYPES = {
    "image" => :image, "video" => :video, "audio" => :audio, "pdf" => :pdf,
    "3d" => :model_3d, "model" => :model_3d, "3d model" => :model_3d,
    "office" => :document, "document" => :document, "ebook" => :ebook
  }.freeze

  # Office and OpenOffice files (CCS-164): Word, Excel, PowerPoint, OpenDocument text, spreadsheet and presentation, and RTF
  DOCUMENT_EXTENSIONS = %w[doc docx xls xlsx ppt pptx odt ods odp rtf].freeze
  EBOOK_EXTENSIONS = %w[epub].freeze

  MODEL_EXTENSIONS = %w[glb gltf obj stl usdz fbx ply].freeze
  EXTENSIONS = { "jpg" => :image, "jpeg" => :image, "png" => :image, "gif" => :image, "webp" => :image, "tif" => :image, "tiff" => :image,
                 "mp4" => :video, "webm" => :video, "mov" => :video, "mp3" => :audio, "wav" => :audio, "m4a" => :audio, "pdf" => :pdf,
                 **MODEL_EXTENSIONS.index_with { :model_3d }, **DOCUMENT_EXTENSIONS.index_with { :document },
                 **EBOOK_EXTENSIONS.index_with { :ebook } }.freeze

  # The index field that is expected to carry each asset's format type (the ingest's format_types_ssim); not in the index yet
  FORMAT_TYPE_FIELD = "format_types_ssim"

  # The index field expected to carry an IIIF Image API info.json URL for each large image, in the same order as
  # digital_asset_large_paths_ssim (an empty string for an image without one). CCS-315 (the DAM field) decides the real name;
  # change it here and nowhere else. Absent today, so every image falls back to its plain file.
  IIIF_INFO_FIELD = "iiif_info_urls_ssim"

  # Audio and video a web browser plays itself. The DAM holds videos as WMV (video/x-ms-wmv), which none plays: such a file gets
  # UNPLAYABLE_VIEWER (the file to download, or a request for a copy) rather than a player that stays blank.
  BROWSER_PLAYABLE = %w[video/mp4 video/webm video/ogg video/quicktime audio/mpeg audio/mp3 audio/wav audio/x-wav audio/wave
                        audio/ogg audio/aac audio/mp4 audio/x-m4a audio/flac audio/webm].freeze
  UNPLAYABLE_VIEWER = "media_viewers/unplayable"
  # Short names for formats whose MIME subtype is not one
  FORMAT_NAMES = { "video/x-ms-wmv" => "WMV", "video/x-msvideo" => "AVI", "video/x-flv" => "FLV", "audio/x-ms-wma" => "WMA" }.freeze

  module_function

  # The Type for a file, from any of what is known about it
  def for(format_type: nil, mime: nil, filename: nil)
    kind = FORMAT_TYPES[format_type.to_s.strip.downcase] || from_mime(mime) || from_extension(filename) || :other
    Type.new(kind: kind, label: LABELS.fetch(kind), viewer: VIEWERS[kind])
  end

  def viewer_for(kind) = VIEWERS.fetch(kind.to_sym, UNSUPPORTED_VIEWER)

  # The viewer for one media item (Collections::DigitalMedia.parse): its kind's, unless it is audio or video a browser cannot play
  def viewer_for_item(item)
    return UNPLAYABLE_VIEWER if %w[audio video].include?(item[:kind].to_s) && !browser_playable?(item[:type], item[:url])
    return UNSUPPORTED_VIEWER if item[:kind].to_s == "model_3d" && !viewable_model?(item[:type], item[:url])

    viewer_for(item[:kind])
  end

  # File extensions browsers play, for a file whose type the DAM sync could not tell (application/octet-stream): the DAM holds
  # .vob, .divx and .m2t videos that way (CCS-481, 2026-11-18), and those must not get a player that stays blank
  PLAYABLE_EXTENSIONS = %w[mp3 wav m4a aac oga ogg opus flac weba webm mp4 m4v mov ogv].freeze

  # Whether a browser plays this audio or video. A known audio or video type decides it; otherwise the file's extension does;
  # a file with neither is left for the browser to try. (CCS-481: the formats the DAM holds and how each is shown are in
  # docs/media-viewer.md.)
  def browser_playable?(mime, url = nil)
    type = mime.to_s.downcase.split(";").first.to_s.strip
    return BROWSER_PLAYABLE.include?(type) if type.match?(%r{\A(audio|video)/})

    extension = file_extension(url)
    extension.blank? || PLAYABLE_EXTENSIONS.include?(extension)
  end

  # Whether model-viewer can show this 3D file: glTF or GLB, by its type or else its file's extension
  def viewable_model?(mime, url)
    VIEWABLE_MODEL_TYPES.include?(mime.to_s.downcase.split(";").first.to_s.strip) || VIEWABLE_MODEL_EXTENSIONS.include?(file_extension(url))
  end

  def file_extension(url)
    File.extname(URI.parse(url.to_s).path.to_s).delete_prefix(".").downcase
  rescue URI::InvalidURIError
    ""
  end

  # "WMV", "AVI", "MP4": a format's short name, from its MIME type or else the file's extension
  def format_name(mime, url)
    type = mime.to_s.downcase
    FORMAT_NAMES[type] || File.extname(URI.parse(url.to_s).path.to_s).delete_prefix(".").upcase.presence || type.split("/").last.to_s.upcase
  rescue URI::InvalidURIError
    type.split("/").last.to_s.upcase
  end

  def from_mime(mime)
    case mime.to_s.downcase
    when %r{\Aimage/} then :image
    when %r{\Avideo/} then :video
    when %r{\Aaudio/} then :audio
    when "application/pdf" then :pdf
    when %r{\Amodel/} then :model_3d
    when "application/epub+zip" then :ebook
    when %r{\Aapplication/(msword|vnd\.ms-(excel|powerpoint)|vnd\.openxmlformats-officedocument\.|vnd\.oasis\.opendocument\.(text|spreadsheet|presentation)|rtf)}
      :document
    end
  end

  def from_extension(filename)
    EXTENSIONS[File.extname(filename.to_s).delete_prefix(".").downcase]
  end
  private_class_method :from_mime, :from_extension
end
