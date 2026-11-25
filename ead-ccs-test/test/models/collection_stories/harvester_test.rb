# frozen_string_literal: true

require "test_helper"

# The offline harvest (bin/rails stories:harvest): reads each source's story list and each story, and keeps a story for the record
# pages only when one of its accession numbers names exactly one record of the source's collection. Everything else goes to the
# curator list. The network and Solr are stand-ins here.
class CollectionStoriesHarvesterTest < ActiveSupport::TestCase
  INDEX = "https://museum.example/from-the-collection"
  BASE = "https://museum.example/from-the-collection/from-the-collection/"

  def source(hold: {})
    CollectionStories::Source.new(name: "Example Museum", collection: "Example Collection", index_url: INDEX,
                                  story_prefix: BASE, hold: hold)
  end

  def story_html(title, body)
    <<~HTML
      <html><head><meta property="og:title" content="#{title}"><meta property="og:image" content="https://museum.example/i/#{title.parameterize}.jpg"></head>
      <body><div class="article"><h1>#{title}</h1><p>A story about the #{title.downcase} in the collection, told by its curator.</p>#{body}</div></body></html>
    HTML
  end

  def pages
    {
      INDEX => <<~HTML,
        <a href="#{BASE}fiddle">Fiddle</a> <a href="#{BASE}fiddle">again</a> <a href="/from-the-collection/from-the-collection/topic">Topic</a>
        <a href="#{BASE}twins">Twins</a> <a href="#{BASE}loan">Loan</a> <a href="#{BASE}held">Held</a>
        <a href="https://museum.example/visit">Visit</a> <a href="#{INDEX}">Index</a>
      HTML
      "#{BASE}fiddle" => story_html("Fiddle", '<img src="https://museum.example/i/00.0099c.JPG"> Example Collection, 2017/8-5/1'),
      "#{BASE}topic" => story_html("Topic", "<p>Many things from many places.</p>"),
      "#{BASE}twins" => story_html("Twins", "<p>Example Collection, 05.0005</p>"),
      "#{BASE}loan" => story_html("Loan", "<p>Lent by a private collector, 09.9999.</p>"),
      "#{BASE}held" => story_html("Held", "<p>Example Collection, 01.3295</p>")
    }
  end

  RECORDS = { "00.0099" => [ "emu-fiddle" ], "05.0005" => %w[emu-a emu-b], "01.3295" => [ "emu-headdress" ] }.freeze

  def harvest(hold: {})
    matcher = ->(collection, accession) { collection == "Example Collection" ? RECORDS.fetch(accession, []) : [] }
    CollectionStories::Harvester.new(sources: [ source(hold: hold) ], fetch: pages.method(:fetch), matcher: matcher).call
  end

  test "the story list is read once per story, under the source's story address only" do
    result = harvest

    urls = result.stories.map(&:url) + result.unmatched.map(&:url)
    assert_equal %w[fiddle topic twins loan held].map { |slug| "#{BASE}#{slug}" }.sort, urls.sort
  end

  test "a story whose accession number names exactly one record of the collection is kept, with the numbers that matched" do
    fiddle = harvest.stories.find { |story| story.title == "Fiddle" }

    assert_equal [ "00.0099" ], fiddle.accession_numbers
    assert_equal [ "emu-fiddle" ], fiddle.record_ids
    assert_equal [ "2017/8-5/1" ], fiddle.unconfirmed
    assert_equal "Example Museum", fiddle.site
    assert_equal "Example Collection", fiddle.collection
    assert_equal "https://museum.example/i/fiddle.jpg", fiddle.image_url
  end

  test "stories with no number, or numbers that match nothing or more than one record, go to the curator list with the reason" do
    unmatched = harvest.unmatched.index_by(&:title)

    assert_equal :no_candidates, unmatched.fetch("Topic").reason
    assert_equal :no_match, unmatched.fetch("Loan").reason
    assert_equal [ "09.9999" ], unmatched.fetch("Loan").candidates
    assert_equal :no_match, unmatched.fetch("Twins").reason
    assert_equal %w[Fiddle Held], harvest.stories.map(&:title).sort # Held matches when nobody has held it
  end

  test "a story a reviewer has held goes to the curator list even when it matches" do
    result = harvest(hold: { "#{BASE}held" => "A broad topic: the curator decides which records it belongs on." })
    held = result.unmatched.find { |story| story.title == "Held" }

    assert_equal :held, held.reason
    assert_equal "A broad topic: the curator decides which records it belongs on.", held.note
    assert_equal [ "01.3295" ], held.candidates
  end

  test "a story that cannot be fetched is reported and the rest still harvested" do
    failing = pages.merge("#{BASE}loan" => nil)
    fetch = ->(url) { failing.fetch(url) || raise(CollectionStories::FetchError, "403 for #{url}") }
    matcher = ->(_collection, accession) { RECORDS.fetch(accession, []) }
    result = CollectionStories::Harvester.new(sources: [ source ], fetch: fetch, matcher: matcher).call

    assert_equal [ "403 for #{BASE}loan" ], result.errors
    assert_includes result.stories.map(&:title), "Fiddle"
    assert_not_includes (result.stories + result.unmatched).map(&:title), "Loan"
  end

  test "the data file it writes is what the record pages read" do
    yaml = CollectionStories::Harvester.yaml(harvest(hold: { "#{BASE}held" => "Held for review." }))
    data = YAML.safe_load(yaml)

    assert_equal [ "Fiddle" ], data["stories"].map { |story| story["title"] }
    assert_equal %w[Held Loan Topic Twins], data["unmatched"].map { |story| story["title"] }.sort
    found = CollectionStories.new(data).for(SolrDocument.new("id" => "emu-fiddle", "accession_number_ssim" => [ "00.0099" ],
                                                             "collection_ssim" => [ "Example Collection" ]))
    assert_equal [ "Fiddle" ], found.map(&:title)
  end
end
