require "test_helper"

class CitationTest < ActiveSupport::TestCase
  URL = "https://ccs.example/catalog/emu-401422".freeze
  ACCESSED = Date.new(2026, 11, 2)

  def document(fields = {})
    SolrDocument.new({
      "id" => "emu-401422", "title_tsim" => [ "Portrait sketch" ], "creator_ssim" => [ "Grainger, Percy Aldridge" ],
      "production_date_ssim" => [ "1922" ], "object_type_ssim" => [ "drawing" ],
      "collection_ssim" => [ "Grainger Museum Collection" ], "accession_number_ssim" => [ "1999.0042" ]
    }.merge(fields))
  end

  def cite(style, fields = {}) = Citation.format(Citation.source_for(document(fields), url: URL), style, accessed: ACCESSED)

  test "APA 7th: author, year, title with its type, holder, accession, link and retrieval date" do
    assert_equal "Grainger, P. A. (1922). Portrait sketch [drawing]. Grainger Museum Collection, University of Melbourne. " \
                 "Accession number 1999.0042. #{URL} Retrieved 2 November 2026.", cite(:apa)
  end

  test "APA joins several creators with an ampersand and puts the title first without one" do
    two = cite(:apa, "creator_ssim" => [ "Grainger, Percy Aldridge", "Smith, John" ])
    assert_match(/\AGrainger, P\. A\., & Smith, J\. \(1922\)\./, two)
    assert_match(/\APortrait sketch \[drawing\] \(1922\)\. Grainger Museum/, cite(:apa, "creator_ssim" => nil))
  end

  test "MLA 9th: inverted first author, title, details, link and access date" do
    assert_equal "Grainger, Percy Aldridge. Portrait sketch. Drawing, 1922, Grainger Museum Collection, University of Melbourne, " \
                 "accession number 1999.0042. #{URL} Accessed 2 Nov. 2026.", cite(:mla)
  end

  test "MLA names the second author in direct order and shortens three or more to et al." do
    assert_match(/\AGrainger, Percy Aldridge, and John Smith\. Portrait/, cite(:mla, "creator_ssim" => [ "Grainger, Percy Aldridge", "Smith, John" ]))
    assert_match(/\AGrainger, Percy, et al\. Portrait/, cite(:mla, "creator_ssim" => [ "Grainger, Percy", "Smith, John", "Lee, Ann" ]))
  end

  test "Chicago 17th: notes and bibliography entry with place and publisher" do
    assert_equal "Grainger, Percy Aldridge. Portrait sketch. Drawing. Grainger Museum Collection, accession 1999.0042. " \
                 "Melbourne: University of Melbourne, 1922. #{URL} (accessed 2 November 2026).", cite(:chicago)
  end

  test "Chicago puts a comma before and with three authors" do
    assert_match(/\AGrainger, Percy, John Smith, and Ann Lee\. /, cite(:chicago, "creator_ssim" => [ "Grainger, Percy", "Smith, John", "Lee, Ann" ]))
  end

  test "Harvard (Australian): author initials, year, title, holder, place, viewed date and link in angle brackets" do
    assert_equal "Grainger, P.A. 1922, Portrait sketch [drawing], Grainger Museum Collection, University of Melbourne, Melbourne, " \
                 "accession number 1999.0042, viewed 2 November 2026, <#{URL}>.", cite(:harvard)
  end

  test "Harvard shortens four or more authors to the first and et al." do
    names = [ "Grainger, Percy", "Smith, John", "Lee, Ann", "Wu, Bo" ]
    assert_match(/\AGrainger, P\. et al\. 1922, /, cite(:harvard, "creator_ssim" => names))
  end

  test "an organisation is named as it is, not inverted or reduced to initials" do
    fields = { "creator_ssim" => [ "C. Wheatstone & Co" ] }
    assert_match(/\AC\. Wheatstone & Co \(1922\)\./, cite(:apa, fields))
    assert_match(/\AC\. Wheatstone & Co\. Portrait sketch\./, cite(:mla, fields))
    assert_match(/\AC\. Wheatstone & Co 1922, /, cite(:harvard, fields))
  end

  test "dates and roles in the creator name are dropped" do
    fields = { "creator_ssim" => [ "Professor William Alexander Osborne (b.1873, d.1967), author", "Osborne & Sons, medical & surgical devices/manufacturer" ] }
    names = Citation.source_for(document(fields), url: URL).creators.map(&:family)
    assert_equal [ "Professor William Alexander Osborne", "Osborne & Sons" ], names
  end

  test "a creator of Unknown is no creator" do
    assert_empty Citation.source_for(document("creator_ssim" => [ "Unknown" ]), url: URL).creators
  end

  test "a record with no date is n.d., or takes the indexed start year, and an approximate date keeps its c." do
    assert_match(/\(n\.d\.\)/, cite(:apa, "production_date_ssim" => nil))
    assert_match(/\(1918\)/, cite(:apa, "production_date_ssim" => [ "not dated" ], "date_start_isi" => 1918))
    assert_match(/\(c\. 1920\)/, cite(:apa, "production_date_ssim" => [ "c. 1920" ]))
    assert_match(/\(1896\)/, cite(:apa, "production_date_ssim" => [ "26 July 1896" ]))
  end

  test "a record with only a title still has a citation in every style, with no empty parts or doubled full stops" do
    sparse = SolrDocument.new("id" => "x-1", "title_tsim" => [ "Untitled box" ])
    Citation::STYLES.each do |style|
      text = Citation.format(Citation.source_for(sparse, url: "https://ccs.example/catalog/x-1"), style, accessed: ACCESSED)
      assert_includes text, "Untitled box", style.to_s
      assert_includes text, "n.d.", style.to_s
      assert_includes text, "https://ccs.example/catalog/x-1", style.to_s
      assert_no_match(/\.\.|,,|\(\)|\[\]|, \.|nil/, text.sub("2026.", ""), style.to_s)
    end
  end

  test "a record with no title is Untitled" do
    assert_includes Citation.format(Citation.source_for(SolrDocument.new("id" => "x"), url: URL), :mla, accessed: ACCESSED), "Untitled"
  end

  test "a reference list is alphabetical by creator, else title, ignoring a leading article" do
    sources = [ { "title_tsim" => [ "The Zither" ], "creator_ssim" => nil }, { "title_tsim" => [ "Beta" ], "creator_ssim" => [ "Zed, Al" ] },
                { "title_tsim" => [ "Alpha" ], "creator_ssim" => [ "Able, Bo" ] } ].map { |f| Citation.source_for(document(f), url: URL) }
    list = Citation.reference_list(sources, :apa, accessed: ACCESSED)
    assert_match(/\AAble/, list[0])
    assert_match(/\AZed/, list[1])
    assert_match(/\AThe Zither/, list[2])
  end

  test "the style comes from a request's parameter, and falls back to APA" do
    assert_equal :harvard, Citation.style_from("harvard")
    assert_equal :apa, Citation.style_from("turabian")
    assert_equal :apa, Citation.style_from(nil)
    assert_equal "Harvard", Citation.label(:harvard)
  end
end
