# frozen_string_literal: true

class CollectionStories
  # The harvest's matcher: the ids of the records whose accession number is exactly this one and whose collection is this one
  # (accession_number_ssim and collection_ssim are string fields, so the match is exact). Two ids are enough to tell "one" from "many".
  module SolrMatcher
    module_function

    def call(collection, accession)
      # Each value is a parameter of a {!term} query, never in the query text (the repo's convention, similar_rows.rb)
      params = { q: "{!term f=accession_number_ssim v=$story_accession}", fq: "{!term f=collection_ssim v=$story_collection}",
                 story_accession: accession.to_s, story_collection: collection.to_s, fl: "id", rows: 2, defType: "lucene" }
      Blacklight.default_index.connection.get("select", params: params).dig("response", "docs").map { |doc| doc["id"] }
    end
  end
end
