# frozen_string_literal: true

class CollectionStories
  # The harvest's matcher: the ids of the records whose accession number is exactly this one and whose collection is this one
  # (accession_number_ssim and collection_ssim are string fields, so the match is exact). Two ids are enough to tell "one" from "many".
  module SolrMatcher
    module_function

    def call(collection, accession)
      params = { q: "accession_number_ssim:#{quote(accession)}", fq: "collection_ssim:#{quote(collection)}", fl: "id", rows: 2,
                 defType: "lucene" }
      Blacklight.default_index.connection.get("select", params: params).dig("response", "docs").map { |doc| doc["id"] }
    end

    # A phrase query: the value in double quotes, its quotes and backslashes escaped
    def quote(value) = %("#{value.to_s.gsub(/["\\]/) { |char| "\\#{char}" }}")
  end
end
