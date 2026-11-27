# frozen_string_literal: true

require "test_helper"

# One story page of a collection's website, read for its card (title, image, summary) and the accession numbers it may be about.
# The markup is a cut-down copy of the shape the University's Squiz Matrix sites use (og: tags, an .article with an h1 and paragraphs).
class CollectionStoriesPageTest < ActiveSupport::TestCase
  URL = "https://grainger.example/from-the-collection/from-the-collection/story-one"

  def html(og_title: "Hardanger fiddle ", og_description: "Hardanger fiddle ", body: nil)
    <<~HTML
      <html><head>
        <meta property="og:title" content="#{og_title}" />
        <meta property="og:description" content="#{og_description}" />
        <meta property="og:image" content="https://grainger.example/__data/assets/image/0011/2357327/Hardanger_Fiddle-detail-web.jpg" />
      </head><body>
        <header><img src="https://grainger.example/__data/assets/image/0008/4712804/Logo_01.0001.png" alt="logo"></header>
        <div class="article">
          <h1>Hardanger fiddle</h1>
          #{body || default_body}
        </div>
        <footer>Phone 03 8344.5270</footer>
      </body></html>
    HTML
  end

  def default_body
    <<~HTML
      <p>Hardanger fiddle</p>
      <p>The Grainger Museum Collection does more than just repose on display in the Museum or sit quietly in boxes and on shelves.</p>
      <p><img src="https://grainger.example/__data/assets/image/0003/2357328/00.0099c.JPG" alt="" />Hardanger fiddle (detail), Grainger Museum Collection</p>
      <p>A baton (Grainger Museum Collection, 00.0039) is mentioned too.</p>
    HTML
  end

  def page(source = html) = CollectionStories::Page.parse(source, url: URL)

  test "the card: og:title without trailing space, og:image and the URL" do
    story = page

    assert_equal "Hardanger fiddle", story.title
    assert_equal URL, story.url
    assert_equal "https://grainger.example/__data/assets/image/0011/2357327/Hardanger_Fiddle-detail-web.jpg", story.image_url
  end

  test "when og:description only repeats the title, the summary is the first real paragraph" do
    assert_equal "The Grainger Museum Collection does more than just repose on display in the Museum or sit quietly in boxes and on shelves.",
                 page.summary
  end

  test "a real og:description is the summary" do
    story = page(html(og_description: "A Norwegian folk fiddle with sympathetic strings, given to Grainger in 1933."))

    assert_equal "A Norwegian folk fiddle with sympathetic strings, given to Grainger in 1933.", story.summary
  end

  test "a long summary is cut at a word and ends with an ellipsis" do
    long = "<p>#{'Percy Grainger collected instruments from many places. ' * 8}</p>"
    summary = page(html(body: long)).summary

    assert_operator summary.length, :<=, CollectionStories::Page::SUMMARY_LENGTH + 1
    assert summary.end_with?("…")
    assert_no_match(/\s…\z/, summary)
  end

  test "candidates come from the article's image file names first, then its text; the header and footer are not read" do
    assert_equal %w[00.0099 00.0039], page.candidates
  end

  test "a caption in an image's alt text counts, and text in separate elements does not run together" do
    body = '<p>Scores.</p><p><img src="/i/medium.jpg" alt="Sleep, 1968-9. Grainger Museum Collection 2017/23/2/2"></p>' \
           "<p>Grainger Museum Collection 2017/23/2/11</p><p>In Nomine</p><script>var id = '99.9999';</script>"

    assert_equal %w[2017/23/2/11 2017/23/2/2], page(html(body: body)).candidates
  end

  test "a page with no og:title falls back to the h1" do
    assert_equal "Hardanger fiddle", page(html(og_title: "")).title
  end
end
