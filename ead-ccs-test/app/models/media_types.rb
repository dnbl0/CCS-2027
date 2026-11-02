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
#   :model_3d   none yet                            needs a 3D viewer (model-viewer or three.js): a new dependency, see docs/media-viewer.md
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
    pdf: "media_viewers/pdf"
  }.freeze

  LABELS = { image: "Image", video: "Video", audio: "Audio", pdf: "PDF document", model_3d: "3D model", other: "File" }.freeze

  # What the DAM calls a file's format (file_properties.format_type in the ingest's assets_json, and format_types_ssim in the
  # index once it carries it), lower case. Anything not listed is looked up by MIME type, then file extension.
  FORMAT_TYPES = {
    "image" => :image, "video" => :video, "audio" => :audio, "pdf" => :pdf,
    "3d" => :model_3d, "model" => :model_3d, "3d model" => :model_3d
  }.freeze

  MODEL_EXTENSIONS = %w[glb gltf obj stl usdz fbx ply].freeze
  EXTENSIONS = { "jpg" => :image, "jpeg" => :image, "png" => :image, "gif" => :image, "webp" => :image, "tif" => :image, "tiff" => :image,
                 "mp4" => :video, "webm" => :video, "mov" => :video, "mp3" => :audio, "wav" => :audio, "m4a" => :audio, "pdf" => :pdf,
                 **MODEL_EXTENSIONS.index_with { :model_3d } }.freeze

  # The index field that is expected to carry each asset's format type (the ingest's format_types_ssim); not in the index yet
  FORMAT_TYPE_FIELD = "format_types_ssim"

  # The index field expected to carry an IIIF Image API info.json URL for each large image, in the same order as
  # digital_asset_large_paths_ssim (an empty string for an image without one). CCS-315 (the DAM field) decides the real name;
  # change it here and nowhere else. Absent today, so every image falls back to its plain file.
  IIIF_INFO_FIELD = "iiif_info_urls_ssim"

  module_function

  # The Type for a file, from any of what is known about it
  def for(format_type: nil, mime: nil, filename: nil)
    kind = FORMAT_TYPES[format_type.to_s.strip.downcase] || from_mime(mime) || from_extension(filename) || :other
    Type.new(kind: kind, label: LABELS.fetch(kind), viewer: VIEWERS[kind])
  end

  def viewer_for(kind) = VIEWERS.fetch(kind.to_sym, UNSUPPORTED_VIEWER)

  def from_mime(mime)
    case mime.to_s.downcase
    when %r{\Aimage/} then :image
    when %r{\Avideo/} then :video
    when %r{\Aaudio/} then :audio
    when "application/pdf" then :pdf
    when %r{\Amodel/} then :model_3d
    end
  end

  def from_extension(filename)
    EXTENSIONS[File.extname(filename.to_s).delete_prefix(".").downcase]
  end
  private_class_method :from_mime, :from_extension
end
