# frozen_string_literal: true

require "test_helper"

class RecordCardComponentTest < ViewComponent::TestCase
  def doc(fields = {}) = SolrDocument.new({ "id" => "emu-2", "title_tsim" => [ "A harp" ] }.merge(fields))

  def card(document = doc, **options) = render_inline NexusCcs::RecordCardComponent.new(document: document, **options)

  test "the title is an h3 and the only link, so the whole card is one target" do
    card(doc("creator_ssim" => [ "Unknown", "Lees, Derwent" ], "production_date_ssim" => [ "1950" ]))

    assert_selector "article.object-card h3.object-card__title a.object-card__link[href='/catalog/emu-2']", text: "A harp"
    assert_selector "a", count: 1
    assert_selector ".object-card__meta", text: "Lees, Derwent · 1950"
  end

  test "the heading level can be changed" do
    card(heading_tag: :h4)

    assert_selector "h4.object-card__title"
  end

  test "a viewable image is shown with an empty alt, since the title names the record" do
    card(doc("thumbnail_path_ssi" => "/digital-assets/thumbs/x.jpg", "licence_type_ssim" => [ "Public domain - Copyright expired" ]))

    assert_selector ".object-card__media img.object-card__image[src*='x.jpg'][alt='']"
    assert_no_selector ".object-card__kicker"
  end

  test "a card with an image can fall back to a text card if the file is missing: the kicker waits hidden and the image reports its failure" do
    card(doc("thumbnail_path_ssi" => "/digital-assets/thumbs/x.jpg", "licence_type_ssim" => [ "Public domain - Copyright expired" ], "object_type_ssim" => [ "harp" ]))

    assert_selector "article.object-card[data-controller='image-fallback']"
    assert_selector "[data-image-fallback-target='media'] img[data-action='error->image-fallback#failed']"
    assert_selector "p.object-card__kicker[hidden][data-image-fallback-target='kicker']", visible: :all
  end

  test "a withheld or sensitive record has no image or asset path, only a text card" do
    withheld = doc("thumbnail_path_ssi" => "/digital-assets/thumbs/w.jpg", "licence_type_ssim" => [ "ICIP Rights" ], "object_type_ssim" => [ "harp" ])
    sensitive = doc("thumbnail_path_ssi" => "/digital-assets/thumbs/s.jpg", "restrictions_tsi" => [ "Culturally sensitive images" ])

    [ withheld, sensitive ].each do |document|
      card(document)

      assert_no_selector "img"
      assert_no_match(%r{digital-assets}, page.native.to_html)
      assert_selector ".object-card--text .object-card__kicker"
      assert_no_selector ".object-card__media"
    end
  end

  test "a card with no image is text: a kicker with the object type (else Record) and the collection, and no box" do
    card(doc("object_type_ssim" => [ "harp" ], "collection_ssim" => [ "Grainger Museum Collection" ]))
    assert_selector ".object-card--text .object-card__kicker", text: "Harp · Grainger Museum Collection"
    assert_no_selector ".object-card__media"

    card
    assert_selector ".object-card__kicker", text: "Record"
  end

  test "the compact variant is marked, and a record with no creator or date has no meta line" do
    card(compact: true)

    assert_selector "article.object-card--compact"
    assert_no_selector ".object-card__meta"
  end
end
