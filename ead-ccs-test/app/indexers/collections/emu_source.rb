module Collections
  # The M&C EMu ecatalogue export
  # Its headers carry their own target mapping in parentheses and several columns
  # share one target, with a "+" prefix to indicate.
  class EmuSource < Source
    # Literal backslash-comma to preserve in-string commas.
    DELIMITER = "\\,".freeze

    IRN            = "eCatalogue/IRN (CACollectionAssetID)".freeze
    ACCESSION      = "Accession Number: (CAAccessionNumber)".freeze
    SUMMARY_DATA   = "Summary Data: (CASourceReferenceNumber)".freeze
    COLLECTION     = "Collection: (CACollection)".freeze
    NAMED          = "Collection Title: (CANamedCollection)".freeze
    PRIMARY_AREA   = "Primary Area: (CAClassification)".freeze
    SECONDARY_TYPE = "Secondary Type: (+CAClassification)".freeze
    RECORD_TYPE    = "Record Type: (CAObjectType)".freeze
    OBJECT_NAME    = "Object Name: (CAObjectType)".freeze
    LEVEL_OF_DESC  = "Level of Description: (CAObjectType)".freeze
    TITLE          = "Title: (CAPrimaryTitle)".freeze
    TAXON          = "Taxon: (CAPrimaryTitle)".freeze
    ALT_TITLES     = "Alternate Titles: (CAAlternateTitles)".freeze
    SERIES_TITLE   = "Series Title: (CAAlternateTitles)".freeze
    COMMON_NAME    = "Common Name: (CAAlternativeTitles)".freeze
    DATE_CREATED   = "Date Created: (CAProductionDate)".freeze
    DATE_START     = "Earliest Date Created: (CADateRangeStart)".freeze
    DATE_END       = "Latest Date Created: (CADateRangeEnd)".freeze
    CREATOR        = "Creator Name [>eParties/Summary Data] (CACreatorName)".freeze
    ROLE           = "Role: (Creator Details)".freeze
    BIRTH          = "Date of Birth: (Creator Details)".freeze
    DEATH          = "Date of Death: (Creator Details)".freeze
    CITATION       = "Preferred Citation: (Creator Details)".freeze
    RECORD_STATUS  = "Record Status: (CAAccessCondition)".freeze
    COLLECTED_BY   = "Collected By: (CAAssociated Entities (subject))".freeze
    CREDIT_LINE    = "Credit Line: (CACreditLine)".freeze
    MEDIUM         = "Medium: (CADescription)".freeze
    EXTENT         = "Extent and Medium: (CADescription)".freeze
    SUBJECT        = "Subject Classification: (CAKeywords)".freeze
    COLL_GROUP     = "Collection Group: (+CAKeywords)".freeze
    PARENT         = "Parent Record: (CAAssociatedEntities(object))".freeze
    RELATED        = "Related Objects: (CAAssociatedEntities(object))".freeze
    RELATED_REL    = "Related Objects Relationship: (CAAssociatedEntities(object))".freeze
    COPYRIGHT      = "Copyright [>eRights/SummaryData]: (CARights/CopyrightNote)".freeze
    CULTURAL_GROUP = "Cultural Group: (+CACreatorName)".freeze
    LANGUAGE_GROUP = "Language Group: (+CACreatorName)".freeze
    SITE           = "Site: (CAPlaceProduction)".freeze
    ASSOC_TYPE     = "Assoc. Type: (CAAssociatedEntitiesSubjects)".freeze
    ASSOC_NAME     = "Name: (CAAssociatedEntitiesSubject)".freeze
    ASSOC_PLACE    = "Place: (CAAssociatEntitiesSubject)".freeze

    # Consolidate broad to specific: "Europe", "United Kingdom", "England", "London".
    CREATION_PLACES = (1..5).map { |n| "CreationPlace#{n}: (CAPlaceProduction)".freeze }.freeze

    private

    def build_document(row)
      # IRN appears to be the most reliable key: Unique with no blanks
      irn = row.value(IRN)
      return nil if irn.nil?

      start_year, end_year = date_range(row)
      creators = row.positional(CREATOR, DELIMITER).compact
      births = row.positional(BIRTH, DELIMITER)
      deaths = row.positional(DEATH, DELIMITER)

      compact_document(
        "id"                  => document_id(irn),
        "source_system_ssi"   => name,
        "source_identifier_ssi" => irn,
        "accession_number_ssim" => row.values(ACCESSION).map { |number| AccessionNumber.restore(number, row.value(COLLECTION)) },
        "source_reference_tsim" => row.values(SUMMARY_DATA),

        "collection_ssim"       => row.values(COLLECTION),
        "named_collection_ssim" => row.values(NAMED),
        "classification_ssim"   => row.list_any([ PRIMARY_AREA, SECONDARY_TYPE ], DELIMITER),
        "object_type_ssim"      => row.list_any([ OBJECT_NAME, LEVEL_OF_DESC ], DELIMITER),
        "format"                => row.values(RECORD_TYPE),

        "title_tsim"             => row.any(TITLE, TAXON),
        "title_si"               => row.value(TITLE) || row.value(TAXON),
        "alternative_title_tsim" => row.any(ALT_TITLES, COMMON_NAME),
        "series_ssim"            => row.list(SERIES_TITLE, DELIMITER),

        "creator_tsim"            => row.list(CREATOR, DELIMITER),
        "creator_ssim"            => row.list(CREATOR, DELIMITER),
        "creator_role_ssim"       => row.list(ROLE, DELIMITER),
        "creator_display_ssim"    => Creators.display(creators, row.positional(ROLE, DELIMITER), births, deaths),
        "creator_birth_ssi"       => row.value(BIRTH),
        "creator_death_ssi"       => row.value(DEATH),
        "creator_birth_isim"      => Creators.years(births),
        "creator_death_isim"      => Creators.years(deaths),
        "preferred_citation_tsim" => row.values(CITATION),

        "subject_ssim"            => row.list_any([ SUBJECT, COLL_GROUP ], DELIMITER),
        "subject_tsim"            => row.list_any([ SUBJECT, COLL_GROUP ], DELIMITER),
        # Associated Entity (Field labels row 5): the collector and the named associated entities.
        "associated_entity_ssim"       => row.list_any([ COLLECTED_BY, ASSOC_NAME ], DELIMITER),
        "associated_entity_role_ssim"  => row.list(ASSOC_TYPE, DELIMITER),
        "associated_entity_place_ssim" => row.list(ASSOC_PLACE, DELIMITER),

        "cultural_group_ssim" => row.list(CULTURAL_GROUP, DELIMITER),
        "language_group_ssim" => row.list(LANGUAGE_GROUP, DELIMITER),

        "production_place_ssim" => row.list_any([ SITE, *CREATION_PLACES ], DELIMITER),

        "production_date_ssim" => row.values(DATE_CREATED),
        "date_start_isi"       => start_year,
        "date_end_isi"         => end_year,

        # The workbook's Material field covers "material techniques, medium and extent"; the EMu
        # export carries it in the two CADescription columns. EMu has no description in this export.
        "material_ssim"    => row.list_any([ MEDIUM, EXTENT ], DELIMITER),
        "credit_line_tsim" => row.values(CREDIT_LINE),
        "rights_ssim"      => row.values(COPYRIGHT),
        "licence_type_ssim" => licence_types(row.values(COPYRIGHT)),

        "parent_record_ssi"                => row.value(PARENT),
        "related_object_ssim"              => row.list(RELATED, DELIMITER),
        "related_object_relationship_ssim" => row.list(RELATED_REL, DELIMITER),

        "access_condition_ssi" => row.value(RECORD_STATUS)
      )
    end

    # Scrape the display string for when there's no explicit range
    # columns to try to catch some more date ranges
    def date_range(row)
      explicit_start = DateRange.explicit_year(row.value(DATE_START))
      explicit_end   = DateRange.explicit_year(row.value(DATE_END))
      return [ explicit_start, explicit_end ] if explicit_start || explicit_end

      DateRange.parse(row.value(DATE_CREATED))
    end
  end
end
