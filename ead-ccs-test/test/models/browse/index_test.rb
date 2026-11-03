require "test_helper"

class BrowseIndexTest < ActiveSupport::TestCase
  KIND = Browse::Kind.find("subjects")
  ROWS = [ [ "Portraits", 190 ], [ "portraits", 3 ], [ "Archaeology", 2482 ], [ "Unknown", 9 ], [ "Zoology", 4 ], [ "[Zebras]", 2 ],
           [ "3rd experiment", 1 ], [ "Ångström", 6 ] ].freeze

  def index = @index ||= Browse::Index.new(KIND, Browse::Index.group(KIND, ROWS))

  test "variants are one entity named by the commonest spelling, counted together" do
    portraits = index.entries.find { |entry| entry.name == "Portraits" }

    assert_equal [ "Portraits", "portraits" ], portraits.variants
    assert_equal 193, portraits.count
    assert_equal 1, index.entries.count { |entry| entry.fold == "portraits" }
  end

  test "noise is not an entity" do
    assert_nil(index.entries.find { |entry| entry.name == "Unknown" })
    assert_nil index.find_value("Unknown")
  end

  test "entries are in A to Z order ignoring case, accents and leading brackets, with digits first" do
    assert_equal [ "3rd experiment", "Ångström", "Archaeology", "Portraits", "[Zebras]", "Zoology" ], index.entries.map(&:name)
    assert_equal %w[0-9 A A P Z Z], index.entries.map(&:letter)
  end

  test "a record's own spelling finds the entity" do
    assert_equal "Portraits", index.find_value("portraits").name
    assert_equal "[Zebras]", index.find_value("Zebras").name
    assert_nil index.find_value("Nothing like it")
  end

  test "a slug finds its entity; a stale readable part is not canonical; an unknown token is nothing" do
    entry = index.find_value("Archaeology")

    assert_equal [ entry, true ], index.find_by_slug(entry.slug)
    stale = index.find_by_slug("old-name-#{entry.token}")
    assert_equal [ entry, false ], stale
    assert_nil index.find_by_slug("archaeology-0000000000")
    assert_nil index.find_by_slug("not a slug")
  end

  test "the filter matches anywhere in the name, ignoring case and accents" do
    assert_equal [ "Ångström" ], index.page(filter: "angstrom").entries.map(&:name)
    assert_equal [ "Archaeology" ], index.page(filter: "AR").entries.map(&:name)
    assert_empty index.page(filter: "qqq").entries
  end

  test "a letter narrows the list and the letter counts follow the filter" do
    page = index.page(letter: "Z")

    assert_equal [ "[Zebras]", "Zoology" ], page.entries.map(&:name)
    assert_equal({ "A" => 2, "P" => 1, "Z" => 2, "0-9" => 1 }, page.letter_counts)
    assert_equal({ "A" => 1 }, index.page(filter: "ar").letter_counts)
    assert_nil index.page(letter: "!!").letter
  end

  test "a long list is paged, and a page out of range is the nearest one" do
    page = index.page(per: 4, page: 2)

    assert_equal [ "[Zebras]", "Zoology" ], page.entries.map(&:name)
    assert_equal 2, page.pages
    assert_equal 2, index.page(per: 4, page: 99).page
    assert_equal 1, index.page(per: 4, page: -3).page
  end

  test "the top entities are the ones with most records" do
    assert_equal %w[Archaeology Portraits], index.top(2).map(&:name)
  end

  test "loading reads one facet of the field and keeps it in the cache" do
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    asked = []
    repository = Object.new
    repository.define_singleton_method(:search) do |params:|
      asked << params
      { "facet_counts" => { "facet_fields" => { "subject_ssim" => { "Archaeology" => 2, "Film" => 1 } } } }
    end

    2.times { Browse::Index.for("subjects", repository: repository) }

    assert_equal 1, asked.size
    assert_equal "subject_ssim", asked.first[:"facet.field"]
    assert_equal(-1, asked.first[:"facet.limit"])
    assert_equal 0, asked.first[:rows]
  ensure
    Rails.cache = original
  end
end
