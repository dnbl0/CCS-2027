# frozen_string_literal: true

require "test_helper"

# The models behind the category, collection, theme and story pages and On this day (docs/categories-themes-stories.md). Solr is
# answered by a stand-in for Discovery.search, so these run without an index.
class DiscoveryContentTest < ActiveSupport::TestCase
  PATH = "/digital-assets/thumbs/0000_013_1_pf.jpg"
  Answer = Struct.new(:documents, :body) do
    def dig(*keys) = body.dig(*keys)
  end

  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @cache }

  def doc(id, fields = {})
    SolrDocument.new({ "id" => id, "title_tsim" => [ "Record #{id}" ], "thumbnail_path_ssi" => PATH, "licence_type_ssim" => [ "Public domain - Copyright expired" ] }.merge(fields))
  end

  # Every Discovery.search answers with these documents and this body (facets); the params of each call are collected
  def with_search(documents, body = {})
    seen = []
    original = Discovery.method(:search)
    Discovery.define_singleton_method(:search) do |params|
      seen << params
      raise Errno::ECONNREFUSED if documents == :down

      Answer.new(documents.respond_to?(:call) ? documents.call(params) : documents, body)
    end
    yield seen
  ensure
    Discovery.define_singleton_method(:search, original)
  end

  # --- Categories ---

  test "a category value's picture is the first record a result card would show one for, never a withheld or sensitive one, never twice" do
    documents = [ doc("a", "region_ssim" => [ "Asia" ], "licence_type_ssim" => [ "ICIP Rights" ]),
                  doc("b", "region_ssim" => [ "Asia" ], "restrictions_tsi" => [ "sensitive" ]),
                  doc("c", "region_ssim" => [ "Asia", "Europe" ]), doc("d", "region_ssim" => [ "Asia" ]) ]
    body = { "facet_counts" => { "facet_fields" => { "region_ssim" => [ "Asia", 40, "Europe", 30, "Unknown", 9, "Africa", 2 ] } } }
    with_search(documents, body) do |seen|
      rows = Categories.values(Categories.find("regions"))

      assert_equal [ "Asia", "Europe", "Africa" ], rows.map { |row| row["value"] } # noise left out
      assert_equal "c", rows[0]["image"]["id"]
      assert_nil rows[1]["image"] # its only record with a picture already gave it to Asia
      assert_nil rows[2]["image"]
      assert_equal 1, seen.size, "one request for the counts and the pictures"
      assert_equal "{!ex=img}region_ssim", seen.first[:"facet.field"]
    end
  end

  test "the Indigenous Collections card has no picture, and a slug finds its value" do
    Rails.cache.write(SuppressedRecord.cache_key("categories/v1/collections"),
                      [ { "value" => "Indigenous Collections", "count" => 3, "image" => { "id" => "x", "title" => "t", "path" => PATH } } ])
    dimension = Categories.find("collections")

    assert_nil Categories.page(dimension).tiles.first.image
    assert_equal "Indigenous Collections", Categories.value_for_slug(dimension, Browse::Slug.build("collections", "Indigenous Collections"))
    assert_nil Categories.value_for_slug(dimension, "indigenous-collections-0000000000")
  end

  # --- Themes ---

  test "the themes file is valid, has at least three themes, and every one is marked placeholder" do
    assert_empty Themes.problems
    assert_operator Themes.all.size, :>=, 3
    Themes.all.each { |theme| assert_match(/placeholder/i, theme.title) }
    assert_match(/PLACEHOLDER/, File.read(Themes::CONFIG_PATH))
  end

  test "a theme's filters are quoted for Solr, and a field that is not a search filter is a problem" do
    theme = Themes::Theme.new(slug: "x", title: "X", intro: "", filters: { "collection_ssim" => [ 'A "quoted" name' ] }, range: { "begin" => 1920, "end" => 1929 }, hero: nil)

    assert_equal [ 'collection_ssim:("A \\"quoted\\" name")', "date_start_isi:[1920 TO 1929]" ], theme.fq
    bad = Themes::Theme.new(slug: "Bad Slug", title: "X", intro: "", filters: { "secret_field" => [ "a" ] }, range: nil, hero: nil)
    assert_equal 2, Themes.problems([ bad ], [ "collection_ssim" ]).size
  end

  # --- Stories ---

  test "a story's Markdown is sanitised, and its embeds are found in their places" do
    parts = Stories.parts(<<~MD)
      Text with <script>alert(1)</script> and <a href="javascript:alert(1)" onclick="x()">a link</a> and <img src=x onerror=y()>.

      {{record emu_mc-1}}

      {{record bad id with spaces}}

      {{search "violin"}}

      {{search "q=harp&f[collection_ssim][]=Grainger Museum Collection&secret=1" "Harps"}}
    MD
    html = parts.first.to_s

    assert_no_match(/<script|<img|<[^>]*\son\w+=|href="javascript/, html) # what is left of a bad tag is escaped text
    embeds = parts.grep(Stories::Embed)
    assert_equal [ :record, :search, :search ], embeds.map(&:kind)
    assert_equal "emu_mc-1", embeds[0].value
    assert_equal "violin", embeds[1].value["q"]
    assert_equal({ "collection_ssim" => [ "Grainger Museum Collection" ] }, embeds[2].value["f"])
    assert_nil embeds[2].value["secret"]
    assert_equal "Harps", embeds[2].heading
  end

  test "the stories folder holds the example story, marked placeholder, and a bad file name is not a story" do
    story = Stories.find("example-story")

    assert_equal "Example story (placeholder)", story.title
    assert_match(/PLACEHOLDER/, File.read(Stories::DIRECTORY.join("example-story.md")))
    assert_nil Stories.find("../config/themes")
  end

  # --- On this day ---

  test "On this day asks for the day and month as the records write it, and keeps the answer for the day" do
    date = Date.new(2026, 11, 8)
    with_search([ doc("a", "production_date_ssim" => [ "8 November 1923" ]), doc("b", "licence_type_ssim" => [ "ICIP Rights" ]) ]) do |seen|
      result = OnThisDay.for(date)

      assert_equal :day, result.kind
      assert_equal [ "a" ], result.documents.map(&:id)
      assert_includes seen.first[:q], "8\\ November*"
      assert_includes seen.first[:q], "*-11-08*"
      OnThisDay.for(date)
      assert_equal 1, seen.size
    end
  end

  test "with no record of the day, On this day shows records from this year some years ago" do
    answer = ->(params) { params[:q].start_with?("production_date") ? [] : [ doc("old", "date_start_isi" => 1926) ] }
    with_search(answer) do
      result = OnThisDay.for(Date.new(2026, 11, 18))

      assert_equal :years_ago, result.kind
      assert_equal 100, result.years_ago
      assert_equal [ "old" ], result.documents.map(&:id)
    end
  end

  test "with Solr down On this day is empty, and Solr is not asked again for a while" do
    with_search(:down) do |seen|
      assert_not OnThisDay.for(Date.new(2026, 11, 18)).any?
      asked = seen.size
      assert_not OnThisDay.for(Date.new(2026, 11, 18)).any?
      assert_equal asked, seen.size
    end
  end

  # --- Creators ---

  test "a maker's facts come only from records that name them alone, and are empty when the fields are" do
    entry = Struct.new(:variants).new([ "Grainger, Percy" ])
    documents = [ SolrDocument.new("creator_ssim" => [ "Grainger, Percy" ], "creator_birth_isim" => [ 1882 ], "creator_death_isim" => [ 1961 ],
                                   "nationality_ssim" => [ "Australian" ], "creator_role_ssim" => [ "composer" ]),
                  SolrDocument.new("creator_ssim" => [ "Someone Else", "Grainger, Percy" ], "creator_birth_isim" => [ 1800, 1882 ], "nationality_ssim" => [ "French" ]) ]
    facts = Browse::Creator.facts(entry, documents)

    assert_equal [ "1882", "1961", "Australian", [ "composer" ] ], [ facts.born, facts.died, facts.nationality, facts.roles ]
    assert_not Browse::Creator.facts(entry, [ SolrDocument.new("creator_ssim" => [ "Grainger, Percy" ]) ]).any?
  end
end
