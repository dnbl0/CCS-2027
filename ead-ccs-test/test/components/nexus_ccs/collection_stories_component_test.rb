# frozen_string_literal: true

require "test_helper"

# "Stories from the collection" on a record page: the record cards' look (object-cards), one card per story, each a link to the
# story on the collection's own site. Drawn only when the record has a story; never a count.
class CollectionStoriesComponentTest < ViewComponent::TestCase
  def story(title: "Hardanger fiddle", image_url: "https://museum.example/i.jpg")
    CollectionStories::Story.new(title: title, url: "https://museum.example/#{title.parameterize}", image_url: image_url,
                                 summary: "A Norwegian folk fiddle.", site: "Grainger Museum", collection: "Grainger Museum Collection",
                                 accession_numbers: [ "00.0099" ])
  end

  test "a section named by its h2, with each story an h3 card in a list" do
    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story, story(title: "Pin") ])

    assert_selector "section#collection-stories.object-cards[aria-labelledby=collection-stories-heading]"
    assert_selector "h2#collection-stories-heading", exact_text: "Stories from the collection"
    assert_selector "ul.object-cards__list > li > article.object-card", count: 2
    assert_selector "article h3.object-card__title a.object-card__link[href='https://museum.example/hardanger-fiddle']",
                    exact_text: "Hardanger fiddle"
    assert_no_selector "a[target]"
  end

  # The picture repeats what the title beside it already says (and many story titles are "From the Collection June 2017"), so it
  # is decorative to a screen reader, as on the record cards: alt="" rather than the title read twice
  test "the card: the image whole and lazy, with empty alt (the title beside it names it); a short summary; the site it is from" do
    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story ])

    assert_selector ".object-card__media img.object-card__image[src='https://museum.example/i.jpg'][alt=''][loading=lazy][decoding=async]"
    assert_selector "p.object-card__summary", exact_text: "A Norwegian folk fiddle."
    assert_selector "p.object-card__meta", exact_text: "Grainger Museum"
  end

  test "the title comes first in the reading order, before the image" do
    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story ])

    assert_operator page.native.to_html.index("object-card__title"), :<, page.native.to_html.index("object-card__image")
  end

  test "a story with no image is a text card" do
    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story(image_url: nil) ])

    assert_selector "article.object-card.object-card--text"
    assert_no_selector "img"
  end

  test "a record the visitor may not view, or a sensitive one, gets text cards: no picture of the object" do
    withheld = SolrDocument.new("id" => "emu-1", "access_condition_ssi" => "Community Restricted")
    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story ], document: withheld)
    assert_selector "article.object-card--text"
    assert_no_selector "img"

    sensitive = SolrDocument.new("id" => "emu-2", "restrictions_tsi" => "Culturally sensitive images")
    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story ], document: sensitive)
    assert_selector "article.object-card--text"
    assert_no_selector "img"
  end

  test "the wording comes from the locale file" do
    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story ])

    assert_selector "h2", exact_text: I18n.t("nexus_ccs.collection_stories.heading")
    assert_selector "p.object-cards__description", exact_text: I18n.t("nexus_ccs.collection_stories.description")
  end

  test "no stories, no section; and no count anywhere" do
    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [])
    assert_no_selector "section"

    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story, story(title: "Pin") ])
    assert_no_text(/\d/) # nothing in the section is a number: no "2 stories", no record count
  end
end
