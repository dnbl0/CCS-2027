require "test_helper"

# The one rule for an image on a page that is not the record's own (galleries, embeds, oEmbed).
class SharedMediaTest < ActiveSupport::TestCase
  def doc(**fields) = SolrDocument.new({ "id" => "x", "thumbnail_path_ssi" => "/digital-assets/thumbs/x.jpg" }.merge(fields.transform_keys(&:to_s)))

  test "the thumbnail is given for a record whose asset may be viewed, whatever the licence tier" do
    [ "Public domain - Copyright expired", "Copyright - Current", nil ].each do |licence|
      assert_equal "/digital-assets/thumbs/x.jpg", SharedMedia.thumbnail_path(doc(licence_type_ssim: Array(licence))), licence.inspect
    end
  end

  test "no thumbnail for a withheld record, whichever way it is withheld" do
    [ doc(licence_type_ssim: [ "ICIP Rights" ]), doc(licence_type_ssim: [ "Restricted Access" ]), doc(access_condition_ssi: [ "Community Restricted" ]) ].each do |document|
      assert_nil SharedMedia.thumbnail_path(document)
      assert_equal :request, SharedMedia.withheld_reason(document)
    end
  end

  test "no thumbnail for a sensitive record, even when the visitor chose to view it" do
    document = doc(restrictions_tsi: [ "Culturally sensitive images. Only select images to be published online" ])

    assert_nil SharedMedia.thumbnail_path(document)
    assert_equal :sensitive, SharedMedia.withheld_reason(document)
  end

  test "a record with no thumbnail has none, and no reason to say so" do
    document = SolrDocument.new("id" => "y")

    assert_nil SharedMedia.thumbnail_path(document)
    assert_nil SharedMedia.withheld_reason(document)
  end
end
