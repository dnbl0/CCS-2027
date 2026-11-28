# frozen_string_literal: true

require "test_helper"

# Every story about a collection object (CollectionStories: the Grainger Museum's and Museums Victoria's) is also a story on this
# site, at /stories/<slug>, beside the hand-written ones in content/stories. A visitor reads it here, not on the other website:
# Museums Victoria's in full (CC BY 4.0, credited); the Grainger Museum's as its summary until its site lets the harvester read the
# full text (docs/collection-stories.md).
class StoriesFromCollectionsTest < ActiveSupport::TestCase
  ENTRY = {
    "title" => "Hardanger fiddle", "url" => "https://museum.example/stories/fiddle", "image_url" => "https://museum.example/i.jpg",
    "image_alt" => "A fiddle", "image_caption" => "The fiddle, front", "image_credit" => "Photographer: A. Person",
    "summary" => "A fiddle.", "site" => "Example Museum", "collection" => "Example Collection", "accession_numbers" => [ "00.0099" ],
    "record_ids" => [ "emu-1" ], "author" => "A. Curator", "licence" => "CC BY", "licence_url" => "https://creativecommons.org/licenses/by/4.0",
    "body" => "<p>All about it <script>alert(1)</script><a href=\"/stories/other\" onclick=\"x()\">more</a>.</p>"
  }.freeze

  def story(entry = ENTRY) = CollectionStories::Story.from(entry)

  test "a collection story has its own address on the site, from its slug or its title" do
    assert_equal "/stories/hardanger-fiddle", story.path
    assert_equal "/stories/a-fiddle", story(ENTRY.merge("slug" => "a-fiddle")).path
    assert_equal "/stories/melba-sings-grainger-s-colonial-song", story(ENTRY.merge("title" => "Melba sings Grainger’s Colonial Song")).path
  end

  test "a Grainger story's date comes from its address, which names the month it was published" do
    url = "https://grainger.unimelb.edu.au/from-the-collection/from-the-collection/from-the-collection-july-2017"

    assert_equal Date.new(2017, 7, 1), story(ENTRY.merge("url" => url)).date
    assert_nil story.date
  end

  test "as a story of the site it keeps its text (sanitised), credit, licence, picture and records" do
    page = Stories.from_collection(story)
    html = page.parts.join

    assert_equal "Example Museum", page.category
    assert_equal [ "emu-1" ], page.records
    assert_equal "A. Curator", page.author
    assert_equal "https://museum.example/i.jpg", page.image.url
    assert_equal "The fiddle, front", page.image.caption
    assert_equal "https://museum.example/stories/fiddle", page.source.url
    assert_equal "CC BY", page.source.licence
    assert page.source.full_text
    assert_match(%r{<a href="/stories/other">more</a>}, html)
    assert_no_match(/<script|onclick/, html)
  end

  test "a story with no text of its own (the Grainger Museum's, for now) shows its summary and says where the full text is" do
    page = Stories.from_collection(story(ENTRY.except("body")))

    assert_not page.source.full_text
    assert_equal [], page.parts
  end

  test "the site's stories include every committed collection story, each at one address, and the hand-written ones" do
    collection = CollectionStories.default.stories
    slugs = Stories.all.map(&:slug)

    assert_operator collection.size, :>=, 20
    assert_equal slugs.uniq, slugs
    assert_includes slugs, "example-story"
    collection.each { |item| assert_equal item.title, Stories.find(item.slug)&.title, item.slug }
  end

  test "Museums Victoria's CSIRAC Collection story is on the site in full, credited, with its objects" do
    page = Stories.find("csirac-collection")

    assert_equal "Museums Victoria", page.category
    assert page.source.full_text
    assert_equal "https://collections.museumsvictoria.com.au/articles/3145", page.source.url
    assert_equal "CC BY", page.source.licence
    assert_includes page.records, "harvested-items_1686199"
    assert_match(/first stored memory digital electronic computer in Australia/, page.parts.join)
  end
end
