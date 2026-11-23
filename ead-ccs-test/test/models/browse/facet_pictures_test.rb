require "test_helper"

class Browse::FacetPicturesTest < ActiveSupport::TestCase
  def doc(id, year: nil, **fields)
    { "id" => id, "src" => "/#{id}.jpg", "year" => year, **Browse::FacetPictures::VALUE_FIELDS.to_h { |field| [ field, Array(fields[field.to_sym]) ] } }
  end

  test "each value takes the first record that carries it, any of its spellings, and no picture twice" do
    pictures = Browse::FacetPictures.new([ doc("a", object_type_ssim: "Painting", creator_ssim: "Bunny, Rupert"), doc("b", object_type_ssim: "Painting"),
                                           doc("c", creator_ssim: "Bunny, R.") ])

    assert_equal "a", pictures.value("object_type_ssim", "Painting").id
    assert_equal "c", pictures.value("creator_ssim", "Bunny, Rupert", "Bunny, R.").id, "a is taken: the next record with either spelling"
    assert_nil pictures.value("subject_ssim", "Travel")
  end

  test "the records the page already shows are taken last" do
    pictures = Browse::FacetPictures.new([ doc("a", object_type_ssim: "Print"), doc("b", object_type_ssim: "Print") ], [ "a" ])
    assert_equal "b", pictures.value("object_type_ssim", "Print").id
    assert_equal "a", pictures.value("object_type_ssim", "Print").id, "nothing else carries it: the shown one after all"
  end

  test "a period takes a record dated within it; the earliest period has no first year" do
    pictures = Browse::FacetPictures.new([ doc("old", year: 850), doc("new", year: 1925) ])
    assert_equal "new", pictures.period(Browse::Periods.before.class.new(1900, 1999, :century)).id
    assert_equal "old", pictures.period(Browse::Periods.before).id
  end
end
