# frozen_string_literal: true

# A wall of square pictures on an Explore page (after Google Arts & Culture's Color Explorer, looked at 2026-11-24): one colour's records
# on Explore by colour, one century's on Explore by time. One Solr request for up to POOL pictured records that may be shown
# (Browse::Cards::THUMBNAIL_FILTERS, AccessPolicy, not sensitive), kept for a day; those the block picks come first (a record whose image
# has the colour as its biggest share), then the rest, by id.
module PictureWall
  Record = Data.define(:id, :title, :src, :tint) # tint: the picture's main colour (its palette's first), shown while it loads, or nil
  SHOWN = 45 # Google's first screenful: nine rows of five
  POOL = 150
  FIELDS = %w[id title_tsim thumbnail_path_ssi colour_palette_ssm].freeze
  HEX = /\A#\h{6}\z/

  module_function

  # key: names the wall in the cache ("colour/teal"); fq: its records; fields: what the block reads.
  # [Record], at most SHOWN; [] when there are none; nil when Solr cannot answer
  def for(key, fq, fields: [], repository: nil, &first)
    records = Rails.cache.fetch(SuppressedRecord.cache_key("picture_wall/v2/#{key}"), expires_in: 1.day, skip_nil: true) do
      response = (repository || Blacklight.default_index).search(params: {
        q: "*:*", defType: "lucene", qt: "select", fq: Array(fq) + Browse::Cards::THUMBNAIL_FILTERS,
        rows: POOL, sort: "id asc", fl: (Browse::Profile::FIELDS + FIELDS + fields).uniq.join(","), facet: false
      })
      shown = response.documents.select { |document| AccessPolicy.view?(document) && !Sensitivity.sensitive?(document) }
      shown = shown.sort_by.with_index { |document, index| [ first.call(document) ? 0 : 1, index ] } if first
      shown.first(SHOWN).map do |document|
        { "id" => document.id.to_s, "title" => Array(document["title_tsim"]).first.to_s.strip.presence || "Untitled record", "src" => document["thumbnail_path_ssi"].to_s,
          "tint" => Array(document["colour_palette_ssm"]).first.to_s[HEX] }
      end
    end
    records&.map { |record| Record.new(id: record["id"], title: record["title"], src: record["src"], tint: record["tint"]) }
  rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable => e
    Rails.logger.warn("Picture wall unavailable (#{key}): #{e.class}")
    nil
  end
end
