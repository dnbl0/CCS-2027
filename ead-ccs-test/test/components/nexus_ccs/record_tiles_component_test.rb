# frozen_string_literal: true

require "test_helper"

class RecordTilesComponentTest < ViewComponent::TestCase
  def doc(fields = {}) = SolrDocument.new({ "id" => "emu-2", "title_tsim" => [ "A harp" ] }.merge(fields))

  def render_tiles(documents, **options)
    render_inline NexusCcs::RecordTilesComponent.new(id: "related", heading: "Related objects", documents: documents, **options)
  end

  test "each record is a link to its page, under a heading that names the group" do
    render_tiles([ doc("object_type_ssim" => [ "harp" ], "collection_ssim" => [ "Grainger Museum" ]) ])

    assert_selector "section#related[aria-labelledby=related-heading] h2#related-heading", text: "Related objects"
    assert_selector "ul.record-tiles__list li.record-tiles__item a.record-tiles__link[href='/catalog/emu-2']", text: "A harp"
    assert_selector ".record-tiles__meta", text: "Harp · Grainger Museum"
  end

  test "a viewable image shows with an empty alt, since the link text names the record" do
    render_tiles([ doc("thumbnail_path_ssi" => "/digital-assets/thumbs/x.jpg", "licence_type_ssim" => [ "Public domain - Copyright expired" ]) ])

    assert_selector "img.record-tiles__image[src*='x.jpg'][alt='']"
  end

  test "a withheld or sensitive record shows no image, as on the result cards" do
    withheld = doc("id" => "emu-3", "thumbnail_path_ssi" => "/digital-assets/thumbs/w.jpg", "licence_type_ssim" => [ "ICIP Rights" ])
    sensitive = doc("id" => "emu-4", "thumbnail_path_ssi" => "/digital-assets/thumbs/s.jpg", "restrictions_tsi" => [ "Culturally sensitive images" ])

    render_tiles([ withheld, sensitive ])

    assert_no_selector "img"
    assert_selector "a.record-tiles__link", count: 2
  end

  test "a record without an image still gets a tile" do
    render_tiles([ doc ])

    assert_no_selector "img"
    assert_selector "a.record-tiles__link", text: "A harp"
  end

  test "no records, no section" do
    render_tiles([])

    assert_no_selector "section"
  end
end
