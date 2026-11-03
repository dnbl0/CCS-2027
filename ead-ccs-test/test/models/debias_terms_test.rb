require "test_helper"
require_relative "../support/debias_helper"

class DebiasTermsTest < ActiveSupport::TestCase
  include DebiasHelper

  def seconds_of
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
  end

  def found(values, field: "title_tsim") = DebiasTerms.scan(field => Array(values)).map(&:found)

  test "the list that ships has no enabled terms, so nothing is ever found" do
    assert_empty DebiasTerms.enabled
    assert_not DebiasTerms.any?
    assert_equal [ "flibbertigibbet" ], DebiasTerms.entries.map(&:term), "the one entry is the disabled, made-up example"
    assert_empty DebiasTerms.scan("title_tsim" => [ "A flibbertigibbet" ])
  end

  test "an empty list finds nothing, for any text" do
    with_debias_terms do
      assert_empty DebiasTerms.scan("title_tsim" => [ "anything at all" ], "description_tsim" => [ "x" * 100_000 ])
    end
  end

  test "a disabled entry is ignored" do
    with_debias_terms(debias_entry("blorp", enabled: false)) { assert_empty found("A blorp") }
  end

  test "a word matches whole words only, in any case, and at the edges of punctuation" do
    with_debias_terms("blorp") do
      assert_equal [ "blorp", "Blorp", "BLORP", "Blorp" ], found([ "a blorp", "Blorp.", "(BLORP)", "Blorp's tale" ])
      assert_equal [ "blorp" ], found("a blorp-zank")
      assert_empty found([ "blorps", "reblorp", "blorpish", "blorp2", "xblorp" ])
    end
  end

  test "case sensitive entries match their own case only" do
    with_debias_terms(debias_entry("Blorp", case: "sensitive")) do
      assert_equal [ "Blorp" ], found([ "Blorp", "blorp", "BLORP" ])
    end
  end

  test "letters beyond ASCII are letters: accents, other scripts, and composed or decomposed forms" do
    with_debias_terms("zorgé", "ξένος", "犬") do
      assert_equal [ "zorgé", "ZORGÉ" ], found([ "a zorgé", "ZORGÉ" ])
      assert_equal [ "zorgé" ], found("zorgé".unicode_normalize(:nfd)), "decomposed text matches the composed term"
      assert_empty found([ "zorgéa", "azorgé", "zorge" ])
      assert_equal [ "ΞΈΝΟΣ", "ξένος" ], found("ΞΈΝΟΣ ξένος")
      assert_empty found("ξένοςα")
      assert_equal [], found("犬は"), "a script with no spaces: the next letter continues the word"
    end
  end

  test "a phrase matches its words in order with any spacing, and not run together or reordered" do
    with_debias_terms(debias_entry("blorp zank", match: "phrase")) do
      assert_equal [ "Blorp   zank", "blorp\nzank" ], found([ "The Blorp   zank here", "blorp\nzank" ])
      assert_empty found([ "blorpzank", "zank blorp", "blorp then zank", "blorp zanks" ])
    end
  end

  test "a prefix matches words that start with it, not words that merely contain it" do
    with_debias_terms(debias_entry("zork", match: "prefix")) do
      assert_equal [ "zork", "Zork" ], found([ "zorkish", "Zorks" ])
      assert_empty found([ "unzork", "azork" ])
    end
  end

  test "regular expression characters in a term are plain text, and such entries are refused at the door" do
    entry, errors = DebiasTerms::Entry.parse(debias_entry("a.*", enabled: true).transform_keys(&:to_s))
    assert_nil entry
    assert_match(/pattern characters/, errors.join)

    # Even an entry that got past the door (built by hand) is escaped, not run
    hostile = DebiasTerms::Entry.new(id: "x", term: "(a+)+$", match: "prefix", case_mode: "insensitive", languages: [ "en" ], fields: [ "all" ],
                                     explanation: "x", alternative: nil, severity: "note", source: "x", reviewed_on: Date.today, enabled: true)
    with_debias_terms(hostile) do
      assert_empty found("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa!")
      assert_equal [ "(a+)+$" ], found("x (a+)+$ y")
    end
  end

  test "a hostile text cannot make the scan slow" do
    with_debias_terms("aaaa", debias_entry("a a a a", match: "phrase")) do
      text = "#{'a ' * 4000}!"
      seconds = seconds_of { DebiasTerms.scan("description_tsim" => [ text ]) }
      assert_operator seconds, :<, 0.5
    end
  end

  test "very long text is read only up to the limit, and a value list is capped" do
    with_debias_terms("blorp") do
      padding = "x " * (DebiasTerms::MAX_LENGTH / 2)
      assert_equal [ "blorp" ], found("blorp #{padding}"), "within the limit"
      assert_empty found("#{padding}#{padding} blorp"), "past the limit is not read"
      seconds = seconds_of { found("y " * 1_000_000) }
      assert_operator seconds, :<, 1

      many = Array.new(DebiasTerms::MAX_VALUES + 10) { "blorp" }
      assert_equal DebiasTerms::MAX_VALUES, found(many).size
      assert_equal DebiasTerms::MAX_MATCHES, found([ "blorp " * 500 ]).size
    end
  end

  test "text that is not valid UTF-8 does not raise" do
    with_debias_terms("blorp") do
      assert_equal [ "blorp" ], found("a \xFF blorp".dup.force_encoding("UTF-8"))
    end
  end

  test "an entry looks only in the fields it names" do
    with_debias_terms(debias_entry("blorp", fields: [ "title" ])) do
      assert_equal 1, DebiasTerms.scan("title_tsim" => [ "blorp" ], "description_tsim" => [ "blorp" ]).size
    end
    with_debias_terms(debias_entry("blorp", fields: [ "subject", "description_tsim" ])) do
      assert_equal %w[description_tsim subject_ssim], DebiasTerms.scan("subject_ssim" => [ "blorp" ], "description_tsim" => [ "blorp" ], "title_tsim" => [ "blorp" ]).map(&:field)
    end
  end

  test "only the text a record page displays is read: other fields are ignored even when they hold the term" do
    with_debias_terms("blorp") do
      assert_empty DebiasTerms.scan("restrictions_tsi" => [ "blorp" ], "collection_ssim" => [ "blorp" ], "id" => "blorp", "credit_line_tsim" => [ "blorp" ])
    end
  end

  test "a find knows its field, value, position and context" do
    with_debias_terms("blorp") do
      match = DebiasTerms.scan("subject_ssim" => [ "nothing", "one two blorp three" ]).first

      assert_equal [ "subject_ssim", 1, 8, 13 ], [ match.field, match.value_index, match.start, match.finish ]
      assert_equal [ "one two ", "blorp", " three" ], match.context
      long = DebiasTerms.scan("title_tsim" => [ "#{'word ' * 30}blorp#{' word' * 30}" ]).first.context
      assert long.first.start_with?("…") && long.last.end_with?("…")
    end
  end

  test "matches come in field order, then position" do
    with_debias_terms("blorp", "zank") do
      matches = DebiasTerms.scan("description_tsim" => [ "zank blorp" ], "title_tsim" => [ "blorp" ])
      assert_equal [ "title_tsim", "description_tsim", "description_tsim" ], matches.map(&:field)
      assert_equal %w[zank blorp], matches.last(2).map(&:found)
    end
  end

  test "a list file that cannot be read, or has a bad or duplicate entry, is skipped without raising" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "terms.yml")
      File.write(path, "terms: [unterminated")
      assert_empty DebiasTerms.send(:load_entries, path)

      File.write(path, { "terms" => [ "not a hash", debias_entry("good").transform_keys(&:to_s), debias_entry("good").transform_keys(&:to_s),
                                      debias_entry("bad*", enabled: true).transform_keys(&:to_s) ] }.to_yaml)
      assert_equal [ "good" ], DebiasTerms.send(:load_entries, path).map(&:term)
      assert_empty DebiasTerms.send(:load_entries, File.join(dir, "missing.yml"))
    end
  end

  test "use puts the original list back afterwards, even after an error" do
    before = DebiasTerms.entries
    assert_raises(RuntimeError) { with_debias_terms("blorp") { raise "boom" } }
    assert_same before, DebiasTerms.entries
  end
end

class DebiasHighlightTest < ActiveSupport::TestCase
  include DebiasHelper

  def highlight(text, **) = DebiasTerms::Highlight.call(text, DebiasTerms.scan("title_tsim" => [ text ]), label: "flagged term:")

  test "the found term is wrapped in a mark with a visually hidden label, and the rest of the text is unchanged" do
    with_debias_terms("blorp") do
      html = highlight("The Blorp & the blorp.")

      assert_equal %(The <mark class="debias-flag"><span class="visually-hidden">flagged term: </span>Blorp</mark> &amp; the <mark class="debias-flag"><span class="visually-hidden">flagged term: </span>blorp</mark>.), html
      assert_equal "The flagged term: Blorp & the flagged term: blorp.", Nokogiri::HTML.fragment(html).text
      assert_predicate html, :html_safe?
    end
  end

  test "markup in the record's text is escaped, never passed through" do
    with_debias_terms("blorp") do
      html = highlight(%(<script>alert(1)</script> blorp <img src=x onerror=alert(2)>))

      assert_no_match(/<script|<img/, html)
      assert_includes html, "&lt;script&gt;"
    end
  end

  test "overlapping finds make one mark" do
    with_debias_terms("blorp zank", debias_entry("zank", match: "word")) do
      assert_equal 1, highlight("blorp zank").scan("<mark").size
    end
  end

  test "text with no finds is returned escaped and unmarked" do
    with_debias_terms("blorp") { assert_equal "a &lt; b", DebiasTerms::Highlight.call("a < b", [], label: "x") }
  end
end
