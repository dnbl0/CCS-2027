# frozen_string_literal: true

# Stand-ins for the DAM API and Solr in the DAM sync tests: no network, no Solr.
module DamFakes
  # An asset as /v2/assets/search returns it (metadata, file_properties and embeds expanded)
  def dam_item(id, accession: "1987.0043", licence: nil, format: "image", updated: "2026-11-13T03:51:40Z", **fields)
    metadata = { "cAAccessionNumber" => [ accession ].compact, "dALicenseType" => [ licence ].compact }
    fields.each { |key, value| metadata[key.to_s] = Array(value) }
    {
      "id" => id, "filename" => "#{id}.jpg", "last_update_date" => updated, "deleted_date" => nil,
      "file_properties" => { "format_type" => format },
      "embeds" => {
        "1000x1000_without_retina" => { "url" => "https://unimelbourne.widen.net/content/#{id}/jpeg/thumb.jpg" },
        "2000xauto_without_retina" => { "url" => "https://unimelbourne.widen.net/content/#{id}/jpeg/large.jpg" },
        "original" => { "url" => "https://unimelbourne.widen.net/content/#{id}/original/#{id}" }
      },
      "metadata" => { "fields" => metadata }
    }
  end

  # A Dam::Client whose searches are answered from a Hash { query => [items] } (nil: every asset)
  class Client
    attr_reader :queries

    def initialize(results) = (@results = results) && (@queries = [])

    def each_page(query: nil, expand: true)
      @queries << query
      items = @results.respond_to?(:call) ? @results.call(query) : @results.fetch(query, @results.fetch(:any, []))
      items.each_slice(100).inject(0) do |seen, page|
        yield page, seen + page.size, items.size
        seen + page.size
      end
    end
  end

  # A Dam::SolrWriter that remembers what it was asked to write
  class Writer
    attr_reader :written

    def initialize = @written = []
    def write(accessions) = (@written << accessions.to_a.sort) && accessions.to_a.size
  end

  # An RSolr client over an in-memory list of documents; atomic "set" updates are applied
  class Solr
    attr_reader :docs, :adds, :commits

    def initialize(docs) = (@docs = docs.to_h { |doc| [ doc["id"], doc ] }) && (@adds = []) && (@commits = 0)

    def get(_path, params:)
      wanted = params[:q].scan(/"((?:[^"\\]|\\.)*)"/).flatten.map { |term| term.gsub(/\\(.)/, '\1') }
      docs = @docs.values.select { |doc| (Array(doc["accession_number_ssim"]) & wanted).any? }
      { "response" => { "docs" => docs.map(&:dup), "numFound" => docs.size } }
    end

    def add(updates)
      @adds << updates
      updates.each do |update|
        doc = @docs.fetch(update["id"])
        update.except("id").each { |field, change| change["set"].nil? ? doc.delete(field) : doc[field] = change["set"] }
      end
    end

    def commit = @commits += 1
  end
end
