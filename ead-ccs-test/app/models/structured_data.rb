# frozen_string_literal: true

# schema.org structured data (JSON-LD) for the site and for a record page (CCS-128). It describes the record, never the file:
# the image is the record's thumbnail, and only for a record in the :open tier that is not sensitive (the same test as the
# results list). A record the policy withholds (AccessPolicy :request, Sensitivity) gets no structured data at all.
module StructuredData
  PUBLISHER = { "@type" => "Organization", "name" => "The University of Melbourne", "url" => "https://www.unimelb.edu.au" }.freeze
  SITE_NAME = "Collections Navigator"
  # Object types and classifications that make a record a work of visual art; any other record is a CreativeWork
  VISUAL_ART = /painting|drawing|print\b|photograph|sculpture|watercolour|etching|lithograph|engraving|collage|artwork/i

  def self.site(base_url)
    {
      "@context" => "https://schema.org", "@type" => "WebSite", "name" => SITE_NAME, "url" => "#{base_url}/", "publisher" => PUBLISHER,
      "potentialAction" => {
        "@type" => "SearchAction",
        "target" => { "@type" => "EntryPoint", "urlTemplate" => "#{base_url}/catalog?q={search_term_string}" },
        "query-input" => "required name=search_term_string"
      }
    }
  end

  # document: a SolrDocument; url: its canonical address. Returns a hash, or nil for a withheld record.
  def self.record(document, base_url:, url:)
    return nil if RobotsPolicy.withheld?(document)

    values = ->(field) { Array(document[field]).map { |value| value.to_s.strip }.compact_blank }
    data = {
      "@context" => "https://schema.org",
      "@type" => (values.call("object_type_ssim") + values.call("classification_ssim")).any?(VISUAL_ART) ? "VisualArtwork" : "CreativeWork",
      "@id" => url, "url" => url, "name" => Description.title(document), "publisher" => PUBLISHER,
      "description" => Description.of(document, length: 500),
      "identifier" => values.call("accession_number_ssim").first,
      "creator" => values.call("creator_ssim").map { |name| { "@type" => "Person", "name" => name } }.presence,
      "dateCreated" => values.call("production_date_ssim").first,
      "material" => values.call("material_ssim").first,
      "keywords" => values.call("subject_ssim").presence&.join(", "),
      "locationCreated" => values.call("production_place_ssim").presence&.map { |place| { "@type" => "Place", "name" => place } },
      "isPartOf" => values.call("collection_ssim").first&.then { |name| { "@type" => "Collection", "name" => name } },
      "creditText" => values.call("credit_line_tsim").first,
      "image" => image(document, base_url)
    }.compact_blank
    data["creator"] = data["creator"].first if data["creator"]&.one?
    data
  end

  # The thumbnail's address, for an :open, non-sensitive record only (nil otherwise)
  def self.image(document, base_url)
    path = document["thumbnail_path_ssi"].presence
    return unless path && AccessPolicy.tier(document) == :open && !Sensitivity.sensitive?(document)

    path.start_with?("http") ? path : "#{base_url}#{path}"
  end

  # The JSON for a <script type="application/ld+json"> element. < > & and the line separators are written as \u escapes, so
  # nothing in a record's text can close the element or start markup.
  def self.to_json_ld(data) = ERB::Util.json_escape(JSON.generate(data))

  # A record's words for a page's title and description
  module Description
    LENGTH = 155

    def self.title(document) = Array(document["title_tsim"]).first.to_s.squish.presence || document.id.to_s

    # Plain text, trimmed at a word. Falls back to what the record says about itself when it has no description.
    def self.of(document, length: LENGTH)
      text = Array(document["description_tsim"]).first.presence || fallback(document)
      plain = CGI.unescapeHTML(ActionController::Base.helpers.strip_tags(text.to_s)).squish
      plain.truncate(length, separator: " ", omission: "…")
    end

    def self.fallback(document)
      kind = Array(document["object_type_ssim"]).first || Array(document["format"]).first || "Record"
      collection = Array(document["collection_ssim"]).first
      creator = Array(document["creator_ssim"]).first
      [ "#{kind.to_s.upcase_first} from the #{collection || 'University of Melbourne collections'}", creator && "by #{creator}" ].compact.join(" ") + "."
    end
  end
end
