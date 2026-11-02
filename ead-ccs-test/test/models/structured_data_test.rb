require "test_helper"

class StructuredDataTest < ActiveSupport::TestCase
  BASE = "https://ccs.example.edu.au"

  def document(fields = {})
    SolrDocument.new({ "id" => "emu-1", "title_tsim" => [ "A work" ], "licence_type_ssim" => [ "Public domain - Copyright expired" ],
                       "thumbnail_path_ssi" => "/digital-assets/thumbs/a.jpg", "digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg" ] }.merge(fields))
  end

  def record(doc) = StructuredData.record(doc, base_url: BASE, url: "#{BASE}/catalog/#{doc.id}")

  test "the site is a WebSite with a SearchAction pointing at the catalog search" do
    data = StructuredData.site(BASE)

    assert_equal "WebSite", data["@type"]
    assert_equal "#{BASE}/catalog?q={search_term_string}", data.dig("potentialAction", "target", "urlTemplate")
    assert_equal "required name=search_term_string", data.dig("potentialAction", "query-input")
  end

  test "a record is a CreativeWork with its own words, its identifier and its collection" do
    data = record(document("description_tsim" => [ "A <b>fine</b> chest" ], "accession_number_ssim" => [ "1973.1" ], "collection_ssim" => [ "University Art Collection" ],
                           "creator_ssim" => [ "Grimwade" ], "subject_ssim" => [ "Furniture", "Design" ]))

    assert_equal "CreativeWork", data["@type"]
    assert_equal "A work", data["name"]
    assert_equal "A fine chest", data["description"]
    assert_equal "1973.1", data["identifier"]
    assert_equal({ "@type" => "Person", "name" => "Grimwade" }, data["creator"])
    assert_equal "Furniture, Design", data["keywords"]
    assert_equal "University Art Collection", data.dig("isPartOf", "name")
    assert_equal "#{BASE}/catalog/emu-1", data["url"]
  end

  test "a painting, print or photograph is a VisualArtwork" do
    assert_equal "VisualArtwork", record(document("object_type_ssim" => [ "oil painting" ]))["@type"]
    assert_equal "VisualArtwork", record(document("classification_ssim" => [ "Photographs" ]))["@type"]
  end

  test "an open, non-sensitive record carries its thumbnail, as an absolute address, and never the large file" do
    data = record(document)

    assert_equal "#{BASE}/digital-assets/thumbs/a.jpg", data["image"]
    assert_not_includes StructuredData.to_json_ld(data), "/large/"
  end

  test "a view-only record has no image" do
    assert_nil record(document("licence_type_ssim" => [ "Copyright - Current" ]))["image"]
  end

  test "a record without a licence has no image, as it is view-only" do
    assert_nil record(document("licence_type_ssim" => nil))["image"]
  end

  test "a record that is withheld or sensitive has no structured data at all" do
    assert_nil record(document("licence_type_ssim" => [ "ICIP Rights" ]))
    assert_nil record(document("access_condition_ssi" => "Community Restricted"))
    assert_nil record(document("restrictions_tsi" => [ "Not for publishing Sensitive images" ]))
  end

  test "the JSON cannot close its script element or start markup" do
    data = record(document("title_tsim" => [ "</script><script>alert(1)</script> & end" ], "credit_line_tsim" => [ "a\u2028b" ], "description_tsim" => [ "<img src=x onerror=alert(1)>text" ]))
    json = StructuredData.to_json_ld(data)

    assert_not_includes json, "</script>"
    assert_not_includes json, "<"
    assert_not_includes json, ">"
    assert_not_includes json, "\u2028"
    assert_equal "</script><script>alert(1)</script> & end", JSON.parse(json)["name"]
    assert_equal "a\u2028b", JSON.parse(json)["creditText"]
  end

  test "a description is plain text trimmed at a word, with a fallback from the record's own fields" do
    long = StructuredData::Description.of(document("description_tsim" => [ "word " * 100 ]))
    assert_operator long.length, :<=, 155
    assert long.end_with?("…")
    assert_equal "Chest from the Museum by Smith.", StructuredData::Description.of(document("object_type_ssim" => [ "chest" ], "collection_ssim" => [ "Museum" ], "creator_ssim" => [ "Smith" ]))
  end
end
