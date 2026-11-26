# frozen_string_literal: true

require "test_helper"

# "Stories from the collection" on a record page, after the National Gallery of Art's article listings: one story is a wide row
# (source, kicker, headline, summary, picture); two or more are a card grid (picture, kicker, headline, summary). Each story is a
# link to the article on the collection's own site. Drawn only when the record has a story; never a count.
class CollectionStoriesComponentTest < ViewComponent::TestCase
  def story(title: "Hardanger fiddle", image_url: "https://museum.example/i.jpg")
    CollectionStories::Story.new(title: title, url: "https://museum.example/#{title.parameterize}", image_url: image_url,
                                 summary: "A Norwegian folk fiddle.", site: "Grainger Museum", collection: "Grainger Museum Collection",
                                 accession_numbers: [ "00.0099" ])
  end

  def record(**fields) = SolrDocument.new({ "id" => "emu-1", "thumbnail_path_ssi" => "/media/emu-1.jpg" }.merge(fields))

  test "a section named by its h2; each story an h3 headline that links to the article, in the same tab" do
    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story, story(title: "Pin") ])

    assert_selector "section#collection-stories[aria-labelledby=collection-stories-heading]"
    assert_selector "h2#collection-stories-heading", exact_text: "Stories from the collection"
    assert_selector "article.story h3.story__title a.story__link[href='https://museum.example/hardanger-fiddle']", exact_text: "Hardanger fiddle"
    assert_no_selector "a[target]"
  end

  test "one story is a wide row: the source, the Article kicker, the headline, the summary and the picture" do
    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story ])

    assert_selector "article.story.story--feature", count: 1
    assert_no_selector "ul"
    assert_selector ".story--feature .story__source", exact_text: "Grainger Museum"
    assert_selector ".story--feature .story__kicker", exact_text: "Article"
    assert_selector ".story--feature p.story__summary", exact_text: "A Norwegian folk fiddle."
    assert_selector ".story--feature .story__media img.story__image[src='https://museum.example/i.jpg']"
  end

  test "two stories are a two-column grid, three or more a three-column grid: a list of cards" do
    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story, story(title: "Pin") ])
    assert_selector "ul.story-grid.story-grid--2 > li > article.story.story--card", count: 2

    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story, story(title: "Pin"), story(title: "Baton"), story(title: "Card") ])
    assert_selector "ul.story-grid.story-grid--3 > li > article.story.story--card", count: 4
    assert_selector ".story--card .story__kicker", text: "Article"
    assert_selector ".story--card p.story__summary", count: 4
  end

  # The headline beside it names the story, so the picture is decorative to a screen reader: alt="" rather than the title read twice
  test "the picture is whole, lazy and decorative, and the headline comes before it in the reading order" do
    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story ])

    assert_selector "img.story__image[alt=''][loading=lazy][decoding=async]"
    html = page.native.to_html
    assert_operator html.index("story__title"), :<, html.index("story__image")
  end

  test "a story without its own picture shows the record's picture of the object" do
    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story(image_url: nil) ], document: record)

    assert_selector "img.story__image[src$='/media/emu-1.jpg']"
  end

  test "when the story's picture will not load, the record's picture is tried, then the card becomes text (no broken image)" do
    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story ], document: record)

    assert_selector "article.story[data-controller='story-image'][data-story-image-fallback-value$='/media/emu-1.jpg']"
    assert_selector "[data-story-image-target='media'] img[data-story-image-target='image'][data-action='error->story-image#fail']"
  end

  test "no picture at all is a text story" do
    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story(image_url: nil) ])

    assert_selector "article.story.story--text"
    assert_no_selector "img"
  end

  test "a record the visitor may not view, or a sensitive one, gets text stories: no picture of the object at all" do
    [ record("access_condition_ssi" => "Community Restricted"), record("restrictions_tsi" => "Culturally sensitive images") ].each do |hidden|
      render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story ], document: hidden)
      assert_selector "article.story--text"
      assert_no_selector "img"
      assert_no_selector "[data-story-image-fallback-value]"
    end
  end

  test "the wording comes from the locale file" do
    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story ])

    assert_selector "h2", exact_text: I18n.t("nexus_ccs.collection_stories.heading")
    assert_selector "p.collection-stories__description", exact_text: I18n.t("nexus_ccs.collection_stories.description")
    assert_selector ".story__kicker", exact_text: I18n.t("nexus_ccs.collection_stories.kicker")
  end

  test "no stories, no section; and no count anywhere" do
    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [])
    assert_no_selector "section"

    render_inline NexusCcs::CollectionStoriesComponent.new(stories: [ story, story(title: "Pin") ])
    assert_no_text(/\d/) # nothing in the section is a number: no "2 stories", no record count
  end
end
