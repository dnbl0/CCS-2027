# frozen_string_literal: true

# What of a record's media a visitor may be shown, and the media themselves, in one place for the viewers that are not the
# record page's own component: the IIIF manifest (IiifManifest) and the comparison page (CompareController). It asks exactly
# what DigitalAssetsComponent asks: AccessPolicy (a :request record shows no asset), and Sensitivity (a sensitive record shows
# none until the visitor chose to view it). Nothing of an asset (not even its path) leaves #images or #media for a record
# that is not #shown?.
class RecordMedia
  Image = Data.define(:url, :thumbnail, :info_url, :alt)

  # session: the visitor's session (for the sensitivity choice); nil means no choice has been made.
  def self.for(document, session: nil)
    viewing = session && Sensitivity.sensitive?(document) && Sensitivity::Choices.new(session).viewing?(document.id)
    new(document, viewing: viewing)
  end

  attr_reader :document

  def initialize(document, viewing: false)
    @document = document
    @viewing = viewing ? true : false
  end

  def tier = @tier ||= AccessPolicy.tier(document)
  def sensitive? = Sensitivity.sensitive?(document)

  # The assets may be put in front of this visitor now
  def shown? = tier != :request && (!sensitive? || @viewing)

  # Whether the record has an image at all, whatever the policy says (for deciding whether to offer anything)
  def images? = large_paths.any?

  # The image(s) the visitor may see; the large file, its thumbnail, its IIIF info.json when the record has one
  def images
    return [] unless shown?

    thumbs = Array(document["digital_asset_paths_ssim"])
    infos = Array(document[MediaTypes::IIIF_INFO_FIELD])
    count = large_paths.size
    large_paths.each_with_index.map do |url, index|
      Image.new(url: url, thumbnail: thumbs[index].presence || url, info_url: infos[index].presence,
                alt: count == 1 ? title : "#{title}, image #{index + 1} of #{count}")
    end
  end

  def title = Array(document["title_tsim"]).first.presence || "Record"
  def accession_number = Array(document["accession_number_ssim"]).first.presence
  def licences = Array(document["licence_type_ssim"]).compact_blank
  def licence = licences.first

  private

  def large_paths = Array(document["digital_asset_large_paths_ssim"]).compact_blank
end
