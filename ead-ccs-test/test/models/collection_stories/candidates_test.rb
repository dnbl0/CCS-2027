# frozen_string_literal: true

require "test_helper"

# The accession numbers a collection story may be about, read from its image file names and its text. Only candidates: the
# harvest keeps one only when it names exactly one record of the story's collection.
class CollectionStoriesCandidatesTest < ActiveSupport::TestCase
  Candidates = CollectionStories::Candidates

  def from_file(url) = Candidates.from_file_name(url)

  def from_text(text) = Candidates.from_text(text)

  test "a file named after the accession number, with a part or view letter" do
    assert_equal [ "00.0099" ], from_file("https://grainger.unimelb.edu.au/__data/assets/image/0003/2357328/00.0099c.JPG")
  end

  test "a GMC prefix and spaces in the file name" do
    assert_equal [ "04.0164" ], from_file("https://example.org/a/GMC%2004.0164.jpg")
    assert_equal [ "04.0164" ], from_file("https://example.org/a/GMC 04.0164.jpg")
  end

  test "numbers inside a longer file name, and an underscore for the point" do
    assert_equal [ "01.0012" ], from_file("https://example.org/image/0008/2418965/1.-01.0012_Front.jpg")
    assert_equal [ "01.3321" ], from_file("https://example.org/image/0015/2303106/01_3321_Label-MF.jpg")
    assert_equal [ "17.0008" ], from_file("https://example.org/image/0010/2567692/17.0008-full.jpg")
    assert_equal [ "1996.5000" ], from_file("https://example.org/image/0009/2390760/1996.5000.jpg")
  end

  test "file names that name no object give nothing, and the folder numbers are never read" do
    %w[IMG_5635.jpg GibsonHarpGuitar_Detail02.jpg Grainger-with-Earle-Kent-1951-web.jpg varieties/thumb.jpg Grainger_Logo_new.png].each do |name|
      assert_empty from_file("https://example.org/__data/assets/image/0006/2866929/#{name}"), name
    end
  end

  test "an accession number in a caption or credit line" do
    assert_equal [ "01.0397" ], from_text("Made by David-Andersen, Christiania, Norway. Grainger Museum Collection, 01.0397. Photograph by Lee McRae")
    assert_equal [ "1996.5000" ], from_text("Oil on canvas, 46 x 38 cm. Grainger Museum Collection. 1996.5000.")
    assert_equal [ "01.3295" ], from_text("Chinese headdress (date unknown), maker unknown, 01.3295, Grainger Museum Collection")
  end

  test "numbers with slashes, with or without the GMC prefix" do
    assert_equal [ "2017/23/2/2" ], from_text("Excerpt, pp. 14-15. Grainger Museum Collection 2017/23/2/2 In Nomine")
    assert_equal [ "2016/1/1/4" ], from_text("GMC 2016/1/1/4")
    assert_equal [ "2017/8-5/1" ], from_text("manuscript by Percy Grainger, 1911-1914,Grainger Museum Collection, 2017/8-5/1 - Dr Heather Gaunt")
  end

  test "dates, measurements and page numbers are not accession numbers" do
    assert_empty from_text("Tie pin, c.1910. In 1905 and 1911-1914, 46 x 38 cm, pp. 14-15, 28 April 1924, op. 72, 3.5 metres")
  end

  test "each number once, in the order found" do
    assert_equal %w[00.0021 00.0039], from_text("00.0021 then 00.0039 and 00.0021 again")
  end
end
