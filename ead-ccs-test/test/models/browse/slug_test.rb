require "test_helper"

class BrowseSlugTest < ActiveSupport::TestCase
  test "spelling variants of one value fold together" do
    assert_equal Browse::Slug.fold("Portraits"), Browse::Slug.fold("portraits")
    assert_equal Browse::Slug.fold("Europe"), Browse::Slug.fold("Europe (?)")
    assert_equal Browse::Slug.fold("London"), Browse::Slug.fold("[London]")
    assert_equal Browse::Slug.fold("Hirschfeld-Mack, Ludwig"), Browse::Slug.fold("Hirschfeld Mack, Ludwig")
    assert_equal Browse::Slug.fold("Île-de-France"), Browse::Slug.fold("Ile de France")
  end

  test "different values do not fold together" do
    assert_not_equal Browse::Slug.fold("Europe"), Browse::Slug.fold("Europe, Eastern")
    assert_not_equal Browse::Slug.token("makers", "Smith, J."), Browse::Slug.token("places", "Smith, J.")
  end

  test "a slug is deterministic, readable, and made of letters, digits and hyphens only" do
    slug = Browse::Slug.build("makers", "Grainger (née Ström), Ella Viola")

    assert_equal slug, Browse::Slug.build("makers", "Grainger (née Ström), Ella Viola")
    assert_match(/\Agrainger-nee-strom-ella-viola-\h{10}\z/, slug)
    assert_match Browse::Slug::PATTERN, slug
  end

  test "a value with nothing readable in it still has a slug" do
    slug = Browse::Slug.build("places", "???")

    assert_match(/\Aplace-\h{10}\z/, slug)
  end

  test "a long value is shortened without ending in a hyphen" do
    slug = Browse::Slug.build("subjects", "word " * 40)
    readable, token = Browse::Slug.parse(slug)

    assert_operator readable.length, :<=, Browse::Slug::READABLE_LENGTH
    assert_not readable.end_with?("-")
    assert_equal Browse::Slug::TOKEN_LENGTH, token.length
  end

  test "parse gives the readable words and the token, and refuses anything else" do
    assert_equal [ "grainger", "4cdea47c6e" ], Browse::Slug.parse("grainger-4cdea47c6e")
    [ "Grainger-4cdea47c6e", "grainger-4cdea47c6", "grainger-zzzzzzzzzz", "a b-4cdea47c6e", "../etc/passwd", "grainger--4cdea47c6e", "", nil, "x\n4cdea47c6e" ].each do |bad|
      assert_nil Browse::Slug.parse(bad), bad.inspect
    end
  end

  test "Solr syntax in a value is escaped in the filter, never run" do
    nasty = %(a" OR id:* OR "b\\)
    filter = Browse.field_query("creator_ssim", [ nasty ])

    assert_equal %(creator_ssim:("a\\" OR id:* OR \\"b\\\\")), filter
  end

  test "a path is built from a value alone, and noise has no page" do
    assert_match %r{\A/browse/places/australia-\h{10}\z}, Browse.path_for("places", "Australia")
    assert_nil Browse.path_for("makers", "Unknown")
    assert_nil Browse.path_for("makers", "Unknown (posters)")
    assert_nil Browse.path_for("makers", "")
    assert_nil Browse.path_for("colours", "Red")
  end
end
