# frozen_string_literal: true

# A record's images as an IIIF Presentation API 3.0 manifest (CCS-57), so Mirador, Universal Viewer and other IIIF viewers can
# open them. Built from RecordMedia, so only the images the visitor may be shown are in it; for a withheld record it has none
# and the controller answers 404 (ManifestsController).
#
# One canvas per image, sized from the file's header (a file whose size cannot be read is left out: a canvas without a size is
# not valid for an image). Each canvas has one painting annotation whose body is the image; when the record carries an IIIF
# Image API info.json (MediaTypes::IIIF_INFO_FIELD) the body also names the image service so the viewer can ask for tiles.
# `rights` is a URI from Creative Commons or RightsStatements.org, so it is set only for the licences that map to one
# (RIGHTS_BY_LICENCE); every manifest also has a requiredStatement with the licence in words.
class IiifManifest
  CONTEXT = "http://iiif.io/api/presentation/3/context.json"
  PROVIDER = { id: "https://www.unimelb.edu.au/", label: "The University of Melbourne" }.freeze

  # licence_type_ssim (lower case) => rights URI. Licences not here have no URI (the spec allows only these two families).
  RIGHTS_BY_LICENCE = {
    "public domain - copyright expired" => "http://creativecommons.org/publicdomain/mark/1.0/",
    "copyright - current" => "http://rightsstatements.org/vocab/InC/1.0/",
    "copyright" => "http://rightsstatements.org/vocab/InC/1.0/"
  }.freeze

  # media: RecordMedia. base_url: "https://host" (no trailing slash), because IIIF ids are absolute URIs.
  # dimensions: ->(path) { [width, height] or nil }
  def initialize(media, base_url:, dimensions: ImageDimensions.method(:for_path))
    @media = media
    @base = base_url.to_s.chomp("/")
    @dimensions = dimensions
  end

  def id = "#{@base}/catalog/#{ERB::Util.url_encode(@media.document.id)}/manifest.json"
  def record_url = "#{@base}/catalog/#{ERB::Util.url_encode(@media.document.id)}"

  # The canvases that can be drawn; none means there is nothing to give
  def canvases
    @canvases ||= @media.images.filter_map.with_index do |image, index|
      size = @dimensions.call(image.url)
      canvas(index + 1, image, *size) if size
    end
  end

  def any? = canvases.any?

  def as_json(*)
    manifest = {
      "@context" => CONTEXT,
      id: id,
      type: "Manifest",
      label: language_map(@media.title),
      metadata: metadata,
      requiredStatement: { label: language_map("Attribution"), value: language_map(statement) },
      provider: [ { id: PROVIDER[:id], type: "Agent", label: language_map(PROVIDER[:label]) } ],
      homepage: [ { id: record_url, type: "Text", label: language_map(@media.title), format: "text/html" } ],
      items: canvases
    }
    manifest[:rights] = rights if rights
    manifest[:thumbnail] = [ thumbnail ] if thumbnail
    manifest.compact
  end

  # The rights URI when every licence of the record maps to the same one
  def rights
    uris = @media.licences.map { |licence| RIGHTS_BY_LICENCE[licence.strip.downcase] }
    uris.first if uris.any? && uris.uniq.size == 1 && uris.first
  end

  private

  def statement
    licences = @media.licences
    "Licence: #{licences.any? ? licences.join('; ') : 'not stated'}. The University of Melbourne."
  end

  def metadata
    rows = []
    rows << { label: language_map("Accession number"), value: { none: [ @media.accession_number ] } } if @media.accession_number
    rows << { label: language_map("Licence"), value: language_map(@media.licences.join("; ")) } if @media.licences.any?
    rows
  end

  def canvas(number, image, width, height)
    canvas_id = "#{id}/canvas/#{number}"
    body = { id: absolute(image.url), type: "Image", format: mime_type(image.url), width: width, height: height }
    body[:service] = [ { id: image.info_url.sub(%r{/info\.json\z}, ""), type: "ImageService3", profile: "level1" } ] if image.info_url
    {
      id: canvas_id, type: "Canvas", label: language_map(image.alt), width: width, height: height,
      items: [ {
        id: "#{canvas_id}/page", type: "AnnotationPage",
        items: [ { id: "#{canvas_id}/page/image", type: "Annotation", motivation: "painting", body: body, target: canvas_id } ]
      } ]
    }
  end

  def thumbnail
    first = @media.images.first
    return unless first && canvases.any?

    { id: absolute(first.thumbnail), type: "Image", format: mime_type(first.thumbnail) }
  end

  def absolute(url) = url.to_s.start_with?("/") ? "#{@base}#{url}" : url

  def mime_type(url)
    case File.extname(url.to_s.split("?").first).downcase
    when ".png" then "image/png"
    when ".gif" then "image/gif"
    when ".webp" then "image/webp"
    else "image/jpeg"
    end
  end

  def language_map(text) = { en: [ text.to_s ] }
end
