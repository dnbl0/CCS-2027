module Collections
  # Records gathered from the collections' public catalogues (Victorian Collections, Museums Victoria, the MELU Herbarium portal)
  # and the Nexus DAM search results, for University collections that have no EMu or Vernon export (data/harvested.csv).
  # One row per record; `collection` is spelled as in config/university_collections.yml, so a collection becomes searchable
  # here as soon as its rows are indexed.
  #
  # Images stay on the catalogue that published them: image_url is a remote thumbnail, used for both the list and the record
  # page. No licence is claimed, so AccessPolicy treats every record as view only.
  class HarvestedSource < Source
    DELIMITER = /\s*[;,]\s*/
    CREATOR_DELIMITER = /\s*;\s*/
    DEFAULT_FORMAT = "Object".freeze
    IMAGE_FORMAT = "Image".freeze

    private

    def build_document(row)
      id = row.value("id")
      title = row.value("title")
      return nil if id.nil? || title.nil?

      date = row.value("date")
      start_year, end_year = DateRange.parse(date)
      creators = row.list("maker_or_collector", CREATOR_DELIMITER)
      accession = row.value("registration_number")

      compact_document(
        "id"                    => document_id(id),
        "source_system_ssi"     => name,
        "source_identifier_ssi" => id,
        "source_url_ssi"        => row.value("record_url"),
        "accession_number_ssim" => [ accession ].compact,

        "collection_ssim"       => row.values("collection"),
        "named_collection_ssim" => row.values("sub_collection"),
        "classification_ssim"   => row.values("classification"),
        "format"                => [ DEFAULT_FORMAT ],

        "title_tsim" => [ title ],
        "title_si"   => title,

        "creator_tsim" => creators, "creator_ssim" => creators, "creator_display_ssim" => creators,
        "subject_ssim" => row.list("keywords", DELIMITER), "subject_tsim" => row.list("keywords", DELIMITER),
        "production_place_ssim" => row.values("place"),
        "production_date_ssim"  => [ date ].compact,
        "date_start_isi" => start_year,
        "date_end_isi"   => end_year,

        "description_tsim" => row.values("description"),
        "credit_line_tsim" => row.values("source").map { |source| "Record from #{source}" }
      ).merge(image_fields(row.value("image_url")))
    end

    # A remote image is both the thumbnail and the record page image; a record without one gets no image fields.
    def image_fields(url)
      return {} unless url&.start_with?("https://")

      {
        "thumbnail_path_ssi" => url,
        "digital_asset_paths_ssim" => [ url ],
        "digital_asset_large_paths_ssim" => [ url ],
        "has_digital_asset_bsi" => true,
        "digital_asset_format_ssim" => [ IMAGE_FORMAT ]
      }
    end
  end
end
