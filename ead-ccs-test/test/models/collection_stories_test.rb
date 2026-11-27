# frozen_string_literal: true

require "test_helper"

# The record page's "Stories from the collection": the reviewed data file (config/collection_stories.yml) is the only source; a
# story belongs on a record only when the record's accession number AND collection both match the story's.
class CollectionStoriesTest < ActiveSupport::TestCase
  STORY = {
    "title" => "Hardanger fiddle", "url" => "https://museum.example/story", "image_url" => "https://museum.example/i.jpg",
    "summary" => "A fiddle.", "site" => "Example Museum", "collection" => "Example Collection", "accession_numbers" => [ "00.0099" ]
  }.freeze

  def doc(accession, collection = "Example Collection")
    SolrDocument.new("id" => "emu-1", "accession_number_ssim" => Array(accession), "collection_ssim" => [ collection ])
  end

  def stories(*entries) = CollectionStories.new("stories" => entries, "unmatched" => [ STORY.merge("accession_numbers" => [ "01.0001" ]) ])

  test "a record whose accession number and collection match has the story" do
    found = stories(STORY).for(doc("00.0099"))

    assert_equal [ "Hardanger fiddle" ], found.map(&:title)
    assert_equal "https://museum.example/story", found.first.url
    assert_equal "Example Museum", found.first.site
  end

  test "the same number in another collection, a near number, or no number: no story" do
    assert_empty stories(STORY).for(doc("00.0099", "Another Collection"))
    assert_empty stories(STORY).for(doc("00.0099a"))
    assert_empty stories(STORY).for(doc("0.0099"))
    assert_empty stories(STORY).for(doc([]))
  end

  test "stories on the curator list are never shown" do
    assert_empty stories.for(doc("01.0001"))
  end

  test "a story without an https address is skipped, and an image that is not https is dropped" do
    assert_empty stories(STORY.merge("url" => "javascript:alert(1)")).for(doc("00.0099"))
    assert_nil stories(STORY.merge("image_url" => "http://museum.example/i.jpg")).for(doc("00.0099")).first.image_url
  end

  test "a story about two records is on both, once each" do
    two = STORY.merge("accession_numbers" => %w[00.0099 00.0100])

    assert_equal 1, stories(two, two).for(doc(%w[00.0099 00.0100])).size
    assert_equal 1, stories(two).for(doc("00.0100")).size
  end

  test "the committed data file links the Bridgeport baton story to both of its batons, and only in their collection" do
    %w[00.0039 00.0021].each do |accession|
      found = CollectionStories.default.for(doc(accession, "Grainger Museum Collection"))

      assert_equal [ "Bridgeport Presentation Baton" ], found.map(&:title), accession
      assert_equal "Grainger Museum", found.first.site
    end
    assert_empty CollectionStories.default.for(doc("00.0039", "University Art Collection"))
  end

  test "the committed Museums Victoria file puts its stories on the objects they are about, read with the Grainger stories" do
    photograph = CollectionStories.default.for(doc("MM 90899.42", "Engineering and Information Technology Collection"))
    meteorite = CollectionStories.default.for(doc("E 15613", "Engineering and Information Technology Collection"))

    assert_includes photograph.map(&:title), "CSIRAC Collection"
    assert_equal [ "Museums Victoria" ], photograph.map(&:site).uniq
    assert_equal [ "The Henbury Meteorite" ], meteorite.map(&:title)
    assert_empty CollectionStories.default.for(doc("MM 90899.42", "Grainger Museum Collection"))
    assert_equal [ "Bridgeport Presentation Baton" ], CollectionStories.default.for(doc("00.0039", "Grainger Museum Collection")).map(&:title)
  end

  test "load reads several files into one set of stories; a missing file adds nothing" do
    Dir.mktmpdir do |dir|
      one, two = File.join(dir, "one.yml"), File.join(dir, "two.yml")
      File.write(one, { "stories" => [ STORY ] }.to_yaml)
      File.write(two, { "stories" => [ STORY.merge("title" => "Second", "url" => "https://museum.example/two") ] }.to_yaml)

      assert_equal [ "Hardanger fiddle", "Second" ], CollectionStories.load(one, two, File.join(dir, "missing.yml")).for(doc("00.0099")).map(&:title)
    end
  end

  test "the committed data file: nothing on the curator list or held by a reviewer is in the stories the site reads" do
    data = YAML.safe_load_file(CollectionStories::PATH)
    shown = Array(data["stories"]).map { |story| story["url"] }
    held = CollectionStories::Source.load.flat_map { |source| source.hold.keys }

    assert_empty shown & Array(data["unmatched"]).map { |story| story["url"] }
    assert_empty shown & held
    Array(data["stories"]).each do |story|
      assert CollectionStories::Story.from(story), "#{story['title']} is not a usable story (https address, title, collection)"
      assert_predicate story["accession_numbers"], :present?, story["title"]
    end
  end

  test "an unreadable file gives no stories and never breaks a page" do
    assert_empty CollectionStories.load(Rails.root.join("tmp/no-such-stories.yml")).for(doc("00.0099", "Grainger Museum Collection"))
  end
end
