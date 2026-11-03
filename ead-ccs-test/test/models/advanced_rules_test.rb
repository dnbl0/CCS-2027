require "test_helper"

# The Advanced search rules (AdvancedRules): how a clause parameter is read, what each match asks Solr, and that no term can
# become Solr syntax outside the "contains" match (which has always read the search tips' syntax).
class AdvancedRulesTest < ActiveSupport::TestCase
  CONFIG = CatalogController.blacklight_config

  def rule(match, query = "", field: "title", op: nil)
    AdvancedRules::Rule.new("0", field, match, op, query)
  end

  def solr(match, query = "", field: "title", default_op: :must, op: nil)
    AdvancedRules.solr_clause(rule(match, query, field: field, op: op), CONFIG.search_fields[field], default_op)
  end

  def built(clause, params = {})
    SearchBuilder.new(CatalogController.new).with({ clause: clause }.merge(params)).to_h
  end

  # --- Reading the parameter ---

  test "a row from an old link has no match and is read as contains" do
    rules = AdvancedRules.rules("0" => { "field" => "title", "query" => "skull" }, "1" => { "field" => "creator", "op" => "must_not", "query" => "x" })

    assert_equal %w[contains contains], rules.map(&:match)
    assert rules.first.legacy?
    assert rules.last.negated?
  end

  test "a match the field does not offer, or one nobody knows, is read as all of these words" do
    rules = AdvancedRules.rules("0" => { field: "description", match: "begins", query: "a" }, "1" => { field: "all_fields", match: "present" },
                                "2" => { field: "title", match: "'; drop", query: "b" })

    assert_equal %w[all all all], rules.map(&:match)
  end

  test "rows that are not hashes, or name no field, are ignored" do
    assert_empty AdvancedRules.rules("0" => "skull", "1" => { query: "x" })
    assert_empty AdvancedRules.rules(nil)
    assert_empty AdvancedRules.rules([ "a" ])
    assert_empty AdvancedRules.rules("a")
  end

  test "only the first MAX_RULES rules are read" do
    clause = (0..30).to_h { |index| [ index.to_s, { field: "title", query: "w#{index}" } ] }

    assert_equal AdvancedRules::MAX_RULES, AdvancedRules.rules(clause).size
  end

  test "ActionController::Parameters are read like a Hash" do
    params = ActionController::Parameters.new(clause: { "0" => { field: "title", match: "phrase", query: "a b" } })

    assert_equal [ "phrase" ], AdvancedRules.rules(params[:clause]).map(&:match)
  end

  test "each field offers the matches it can answer" do
    assert_equal %w[contains all phrase begins not present empty], AdvancedRules.matches_for("title")
    assert_equal %w[contains all phrase not present empty], AdvancedRules.matches_for("description")
    assert_equal %w[contains all phrase not], AdvancedRules.matches_for("all_fields")
  end

  test "a rule asks for something when it has words or is a presence test" do
    assert rule("empty").active?
    assert rule("present").active?
    assert rule("all", "skull").active?
    assert_not rule("all", "  ").active?
    assert_not rule("contains", "").active?
  end

  # --- What each match asks of Solr ---

  test "all of these words: each word is required and quoted, with the field's own edismax settings" do
    op, query = solr("all", "skull bone")

    assert_equal :must, op
    assert_equal "+\"skull\" +\"bone\"", query[:edismax][:query]
    assert_equal "${title_qf}", query[:edismax][:qf]
  end

  test "the form's any choice makes an including rule a should" do
    assert_equal :should, solr("all", "skull", default_op: :should).first
    assert_equal :should, solr("phrase", "skull", default_op: :should).first
    assert_equal :should, solr("present", default_op: :should).first
  end

  test "a row's own op is not used by the translation: SearchBuilder passes it as the default" do
    clause = { "0" => { field: "title", match: "all", query: "skull", op: "should" } }
    bool = built(clause)[:json][:query][:bool]

    assert_equal 1, bool[:should].size
    assert_nil bool[:must]
  end

  test "this exact phrase: the words in one pair of quotes" do
    assert_equal "\"human skull\"", solr("phrase", "human   skull").last[:edismax][:query]
  end

  test "does not contain: always leaves records out, and any of the words does it" do
    op, query = solr("not", "skull bone", default_op: :should)

    assert_equal :must_not, op
    assert_equal "\"skull\" \"bone\"", query[:edismax][:query]
    assert_equal "1", query[:edismax][:mm]
  end

  test "begins with: a prefix of the string field, for the spellings a title may have, the term as a value" do
    op, query = solr("begins", "skull of")
    prefixes = query[:bool][:should]

    assert_equal :must, op
    assert_equal [ "title_si" ], prefixes.map { |item| item[:prefix][:f] }.uniq
    assert_equal [ "skull of", "Skull of", "Skull Of" ], prefixes.map { |item| item[:prefix][:v] }
    assert_equal %w[creator_ssim subject_ssim], %w[creator subject].map { |field| solr("begins", "x", field: field).last[:bool][:should].first[:prefix][:f] }
  end

  test "has a value and is empty: a fixed query on the field, no term" do
    assert_equal({ lucene: { query: "description_tsim:[* TO *]" } }, solr("present", field: "description").last)
    assert_equal({ lucene: { query: "*:* -creator_tsim:[* TO *]" } }, solr("empty", "ignored words", field: "creator").last)
  end

  test "a rule with no words, and the plain contains match, are left to Blacklight" do
    assert_nil solr("all", "   ")
    assert_nil solr("phrase", "!!!")
    assert_nil solr("contains", "skull")
    assert_nil solr("begins", "***")
  end

  # --- Hostile terms ---

  HOSTILE = [ "x}{!lucene v='*:*'} +title_tsim:a", "skull\" OR \"1", "\\\" -* ~ ^ [ ] { } ( ) : / !", "{!func}1 OR *:*", "a\nb\tc", "title_tsim:* OR creator_tsim:*" ].freeze

  test "in every fixed reading a hostile term becomes quoted words only" do
    %w[all phrase not].each do |match|
      HOSTILE.each do |term|
        text = solr(match, term)&.last&.dig(:edismax, :query)
        next if text.nil?

        assert_match(/\A(\+?"[\p{L}\p{N}'’.,&-]+(\s|"\z)?)+/, text, "#{match}: #{term.inspect} gave #{text.inspect}")
        assert_no_match(/[{}\[\]()!:\\\/~^*]/, text.delete('"'), "#{match}: #{term.inspect} gave #{text.inspect}")
        assert_equal 0, text.count("\"") % 2, "quotes balanced in #{text.inspect}"
      end
    end
  end

  test "a hostile term in begins with stays a JSON value of a prefix query" do
    HOSTILE.each do |term|
      queries = solr("begins", term)&.last
      next unless queries

      queries[:bool][:should].each { |item| assert_equal %i[f v], item[:prefix].keys }
      assert_no_match(/[{}\[\]()!:\\\/~^*"]/, queries[:bool][:should].first[:prefix][:v])
    end
  end

  test "a term is cut to MAX_TERM_LENGTH" do
    text = solr("phrase", "word " * 200).last[:edismax][:query]

    assert_operator text.length, :<=, AdvancedRules::MAX_TERM_LENGTH + 2
  end

  test "hostile text in the contains match is the visitor's own syntax, as it has always been" do
    bool = built({ "0" => { field: "title", query: "skull OR bone" } })[:json][:query][:bool]

    assert_equal "skull OR bone", bool[:must].first[:edismax][:query]
  end

  # --- The whole request ---

  test "a request with only a presence rule is a search, and an empty request is not" do
    bool = built({ "0" => { field: "creator", match: "present" } })[:json][:query][:bool]

    assert_equal "creator_tsim:[* TO *]", bool[:must].first[:lucene][:query]
    assert_nil built({ "0" => { field: "creator", match: "all", query: " " } })[:json]
  end

  test "all and any join the including rules; does not contain always leaves out" do
    clause = { "0" => { field: "title", match: "all", query: "skull" }, "1" => { field: "creator", match: "phrase", query: "ann" },
               "2" => { field: "subject", match: "not", query: "bone" } }
    all = built(clause, { op: "must" })
    any = built(clause, { op: "should" })

    assert_equal 2, all[:json][:query][:bool][:must].size
    assert_equal 1, all[:json][:query][:bool][:must_not].size
    assert_equal 2, any[:json][:query][:bool][:should].size
    assert_equal 1, any[:json][:query][:bool][:must_not].size
    assert_nil any[:mm]
    assert_nil all[:mm]
  end

  test "the same field twice is two rules" do
    clause = { "0" => { field: "title", match: "all", query: "skull" }, "1" => { field: "title", match: "not", query: "bone" } }
    bool = built(clause)[:json][:query][:bool]

    assert_equal 1, bool[:must].size
    assert_equal 1, bool[:must_not].size
  end

  test "an old row gives the same Solr parameters as Blacklight's own code" do
    clauses = [ { "0" => { field: "title", query: "skull" } },
                { "0" => { field: "all_fields", op: "must_not", query: "skull" }, "1" => { field: "creator", op: "should", query: "ann \"x\"" } },
                { "0" => { field: "title", query: "skull OR bone" }, "1" => { field: "subject", query: "" }, "2" => { field: "nope", query: "x" } },
                { "0" => { field: "title", op: "bogus", query: "skull" } } ]

    clauses.each do |clause|
      [ {}, { op: "should" } ].each do |extra|
        builder = SearchBuilder.new(CatalogController.new).with({ clause: clause }.merge(extra))
        mine = Blacklight::Solr::Request.new
        theirs = Blacklight::Solr::Request.new
        builder.add_adv_search_clauses(mine)
        Blacklight::Solr::SearchBuilderBehavior.instance_method(:add_adv_search_clauses).bind_call(builder, theirs)

        assert_equal theirs.to_h, mine.to_h, "#{clause.inspect} #{extra.inspect}"
      end
    end
  end

  # --- The form's rows ---

  FIELDS = %w[all_fields title creator subject description].freeze

  test "each field fills its fixed row with the first rule that names it; the others are extra rows in order" do
    clause = { "3" => { field: "title", query: "a" }, "4" => { field: "title", match: "not", query: "b" }, "5" => { field: "creator", query: "c" }, "9" => { field: "title", query: "d" } }
    layout = AdvancedRules.layout(clause, FIELDS)

    assert_equal "a", layout.fixed["title"].query
    assert_equal "c", layout.fixed["creator"].query
    assert_nil layout.fixed["subject"]
    assert_equal %w[b d], layout.extras.map(&:query)
  end

  test "at most MAX_EXTRA_ROWS extra rows, and one more blank row only while there is room" do
    clause = (0..15).to_h { |index| [ index.to_s, { field: "title", query: "w#{index}" } ] }

    assert_equal AdvancedRules::MAX_EXTRA_ROWS, AdvancedRules.layout(clause, FIELDS, add: true).extras.size
    assert_equal 1, AdvancedRules.layout({}, FIELDS, add: true).extras.size
    assert_empty AdvancedRules.layout({}, FIELDS).extras
  end

  test "remove leaves one extra row out, and never a fixed one" do
    clause = { "0" => { field: "title", query: "a" }, "7" => { field: "title", query: "b" }, "8" => { field: "title", query: "c" } }

    assert_equal [ "c" ], AdvancedRules.layout(clause, FIELDS, remove: "7").extras.map(&:query)
    assert_equal "a", AdvancedRules.layout(clause, FIELDS, remove: "0").fixed["title"].query
  end

  # --- Words for the pill, history and saved search names ---

  test "a rule reads in words" do
    assert_equal "does not contain “skull”", AdvancedRules.describe(rule("not", "skull"))
    assert_equal "does not contain “skull”", AdvancedRules.describe(rule("contains", "skull", op: "must_not"))
    assert_equal "skull", AdvancedRules.describe(rule("contains", "skull"))
    assert_equal "begins with “Ann”", AdvancedRules.describe(rule("begins", "Ann"))
    assert_equal "has a value", AdvancedRules.describe(rule("present"))
    assert_equal "is empty", AdvancedRules.describe(rule("empty"))
  end
end
