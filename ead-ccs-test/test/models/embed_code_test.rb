require "test_helper"

class EmbedCodeTest < ActiveSupport::TestCase
  def code(title: "A <b>\"title\"</b>") = EmbedCode.new(src: "https://example.org/embed/records/x?a=1&b=2", title: title, width: 480, height: 240)

  test "the fixed snippet is one iframe with a title, a size, no border and lazy loading" do
    html = Nokogiri::HTML5.fragment(code.fixed).at("iframe")

    assert_equal "https://example.org/embed/records/x?a=1&b=2", html["src"]
    assert_equal "A <b>\"title\"</b>", html["title"]
    assert_equal [ "480", "240" ], [ html["width"], html["height"] ]
    assert_equal "lazy", html["loading"]
    assert_includes html["style"], "border:0"
  end

  test "the responsive snippet fills its column up to the width" do
    html = Nokogiri::HTML5.fragment(code.responsive).at("iframe")

    assert_includes html["style"], "width:100%"
    assert_includes html["style"], "max-width:480px"
    assert_includes html["style"], "height:240px"
    assert_nil html["width"]
  end

  test "a title cannot break out of its attribute" do
    assert_not_includes code(title: %("><script>alert(1)</script>)).fixed, "<script>"
  end

  test "a consumer's maximum size is honoured, never exceeded, and 0 or junk is ignored" do
    assert_equal [ 300, 200 ], code.fitted(max_width: "300", max_height: "200").then { |c| [ c.width, c.height ] }
    assert_equal [ 480, 240 ], code.fitted(max_width: "9999", max_height: "x").then { |c| [ c.width, c.height ] }
    assert_equal [ 480, 240 ], code.fitted(max_width: "0", max_height: nil).then { |c| [ c.width, c.height ] }
  end

  test "a record that has a notice is given a taller frame than one with an image only" do
    open = SolrDocument.new("id" => "a", "title_tsim" => [ "A" ], "licence_type_ssim" => [ "Public domain - Copyright expired" ], "thumbnail_path_ssi" => "/x.jpg")
    withheld = SolrDocument.new("id" => "b", "title_tsim" => [ "B" ], "licence_type_ssim" => [ "ICIP Rights" ], "thumbnail_path_ssi" => "/x.jpg")

    assert_operator EmbedCode.for_record(withheld, src: "x").height, :>, EmbedCode.for_record(open, src: "x").height
  end
end
