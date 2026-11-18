# frozen_string_literal: true

module Colour
  # rake colour:write: the colours in record_colours into the writable core (DAM_SOLR_URL), as Solr atomic updates:
  #
  #   colour_ssim         the colour names (the Colour filter and the colour browse page)
  #   colour_palette_ssm  the palette's hex values, biggest first
  #   colour_digest_ssi   a digest of the two, so only the records whose colours changed are sent
  #
  # A record gets colours only while it has a viewable image and the colours are of its current thumbnail; otherwise its colour fields
  # are removed (a record whose licence was withdrawn drops out of the colour pages on the next run).
  class IndexWriter
    FIELDS = %w[colour_ssim colour_palette_ssm colour_digest_ssi].freeze
    QUERY = "has_digital_asset_bsi:true OR colour_digest_ssi:[* TO *]"

    def initialize(solr:)
      @solr = solr
    end

    # Returns how many records were updated
    def write
      colours = RecordColour.extracted.pluck(:record_id, :image_url, :palette, :buckets).to_h { |id, *rest| [ id, rest ] }
      changes = []
      WritableCore.each_batch(@solr, q: QUERY, fl: "id,has_digital_asset_bsi,thumbnail_path_ssi,colour_digest_ssi") do |docs|
        docs.each do |doc|
          fields = self.class.fields_for(doc, colours[doc["id"]])
          changes << { "id" => doc["id"] }.merge(fields) unless fields["colour_digest_ssi"] == doc["colour_digest_ssi"]
        end
      end
      WritableCore.update(@solr, changes)
    end

    # The colour fields of a record (all nil when it should have none). colours: [ image_url, palette, buckets ] from record_colours.
    def self.fields_for(doc, colours)
      image_url, palette, buckets = colours
      current = colours && doc["has_digital_asset_bsi"] == true && image_url == doc["thumbnail_path_ssi"] && buckets.present?
      return FIELDS.index_with { nil } unless current

      fields = { "colour_ssim" => buckets, "colour_palette_ssm" => palette.map { |swatch| swatch["hex"] } }
      fields.merge("colour_digest_ssi" => Digest::SHA256.hexdigest(fields.to_json))
    end
  end
end
