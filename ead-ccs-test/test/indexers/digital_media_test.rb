require "test_helper"

class DigitalMediaTest < ActiveSupport::TestCase
  MEDIA = Collections::DigitalMedia.new("X.1" => [ { "kind" => "video", "file" => "a b.mp4", "type" => "video/mp4", "label" => "Film" } ])

  test "a record whose accession has media gains the media fields and format" do
    document = MEDIA.attach("accession_number_ssim" => [ "X.1" ], "digital_asset_format_ssim" => [ "Image" ])

    assert_equal [ "video|video/mp4|/digital-assets/media/a%20b.mp4|Film" ], document["digital_media_ssim"]
    assert_equal [ "Image", "Video" ], document["digital_asset_format_ssim"]
    assert_equal true, document["has_digital_asset_bsi"]
  end

  test "entries parse back" do
    assert_equal({ kind: "video", type: "video/mp4", url: "/u", label: "Film", captions: nil, transcript: nil }, Collections::DigitalMedia.parse("video|video/mp4|/u|Film"))
  end

  test "captions and a transcript, when the entry has them, are stored after the label and parse back" do
    media = Collections::DigitalMedia.new("X.1" => [ { "kind" => "audio", "file" => "a.mp3", "type" => "audio/mpeg", "label" => "Talk", "captions" => "a.vtt", "transcript" => "a.html" } ])
    entry = media.attach("accession_number_ssim" => [ "X.1" ])["digital_media_ssim"].first

    assert_equal "audio|audio/mpeg|/digital-assets/media/a.mp3|Talk|/digital-assets/media/a.vtt|/digital-assets/media/a.html", entry
    assert_equal({ kind: "audio", type: "audio/mpeg", url: "/digital-assets/media/a.mp3", label: "Talk",
                   captions: "/digital-assets/media/a.vtt", transcript: "/digital-assets/media/a.html" }, Collections::DigitalMedia.parse(entry))
  end

  test "a record without media is unchanged" do
    document = { "accession_number_ssim" => [ "Y" ] }
    assert_equal document, MEDIA.attach(document)
  end
end
