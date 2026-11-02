require "test_helper"

class RecordMediaTest < ActiveSupport::TestCase
  def document(extra = {})
    SolrDocument.new({ "id" => "emu-1", "title_tsim" => [ "A portrait" ], "accession_number_ssim" => [ "13.0028" ],
                       "licence_type_ssim" => [ "Public domain - Copyright expired" ],
                       "digital_asset_large_paths_ssim" => [ "/digital-assets/large/a.jpg", "/digital-assets/large/b.jpg" ],
                       "digital_asset_paths_ssim" => [ "/digital-assets/thumbs/a.jpg", "/digital-assets/thumbs/b.jpg" ] }.merge(extra))
  end

  test "an open record shows its images, named by position, with the IIIF info.json where the record has one" do
    media = RecordMedia.new(document(MediaTypes::IIIF_INFO_FIELD => [ "https://iiif.example.org/a/info.json", "" ]))

    assert media.shown?
    assert_equal [ "/digital-assets/large/a.jpg", "/digital-assets/large/b.jpg" ], media.images.map(&:url)
    assert_equal [ "https://iiif.example.org/a/info.json", nil ], media.images.map(&:info_url)
    assert_equal [ "A portrait, image 1 of 2", "A portrait, image 2 of 2" ], media.images.map(&:alt)
  end

  test "a view-only record shows its images" do
    assert RecordMedia.new(document("licence_type_ssim" => [ "Copyright - Current" ])).images.any?
  end

  test "a withheld record has no images at all, though it has them in the index" do
    media = RecordMedia.new(document("licence_type_ssim" => [ "ICIP Rights" ]))

    assert media.images?
    assert_not media.shown?
    assert_empty media.images
  end

  test "a sensitive record shows nothing until the visitor has chosen to view it" do
    sensitive = document("restrictions_tsi" => [ "Culturally sensitive images" ])

    assert_empty RecordMedia.for(sensitive, session: {}).images
    assert_empty RecordMedia.for(sensitive, session: { Sensitivity::Choices::KEY => { "emu-1" => "hide" } }).images
    assert_equal 2, RecordMedia.for(sensitive, session: { Sensitivity::Choices::KEY => { "emu-1" => "view" } }).images.size
  end

  test "a choice to view does not show a withheld record" do
    withheld = document("restrictions_tsi" => [ "Culturally sensitive" ], "licence_type_ssim" => [ "Restricted Access" ])

    assert_empty RecordMedia.for(withheld, session: { Sensitivity::Choices::KEY => { "emu-1" => "view" } }).images
  end
end
