require "test_helper"
require_relative "../support/dam_fakes"

class DamAssetTest < ActiveSupport::TestCase
  include DamFakes

  test "the DAM's metadata fields map to the record page's media metadata" do
    item = dam_item("x1", accession: " EN.00150 ", licence: "All Rights reserved (UoM)", dAAdvisory1: "No Advisory",
                          dAAssetRights: [ "Ask first", "Credit the University" ], dACreatorNameRole: "Lee McRae (Photographer)",
                          cACollection1: "Engineering and IT Collection", dAwebdisplaysequence: "3")
    attributes = DamAsset.attributes_from_api(item)

    assert_equal "EN.00150", attributes[:accession_number]
    assert_equal "All Rights reserved (UoM)", attributes[:licence]
    assert_equal "No Advisory", attributes[:advisory]
    assert_equal "Ask first; Credit the University", attributes[:terms_of_use]
    assert_equal "Lee McRae (Photographer)", attributes[:producer]
    assert_equal "Engineering and IT Collection", attributes[:collection]
    assert_equal 3, attributes[:display_sequence]
  end

  test "blank fields are nil, and only the embed links (which do not expire) are kept" do
    item = dam_item("x2", accession: nil, licence: nil)
    item["thumbnails"] = { "300px" => { "url" => "https://previews.example/x2?sig.expires=1" } }
    attributes = DamAsset.attributes_from_api(item)

    assert_nil attributes[:accession_number]
    assert_nil attributes[:licence]
    assert_equal %w[large original thumbnail], attributes[:urls].keys.sort
    assert attributes[:urls].values.all? { |url| url.start_with?("https://unimelbourne.widen.net/") }
  end

  test "a PDF's thumbnail is the DAM's document thumbnail, and it has no large image" do
    item = dam_item("p1", format: "pdf")
    item["embeds"]["document_thumbnail"] = { "url" => "https://unimelbourne.widen.net/content/p1/png/doc.png" }
    urls = DamAsset.attributes_from_api(item)[:urls]

    assert_equal "https://unimelbourne.widen.net/content/p1/png/doc.png", urls["thumbnail"]
    assert_nil urls["large"]
  end
end
