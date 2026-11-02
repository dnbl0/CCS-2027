require "test_helper"

# CCS-39: which fields held the visitor's words, and where. The Solr parameters are display-only; the last test proves it against the core.
class SearchHighlightingTest < ActiveSupport::TestCase
  def state(params) = Blacklight::SearchState.new(params.with_indifferent_access, CatalogController.blacklight_config)

  def match(entry) = SearchHighlighting::Match.new(entry)

  # --- What is asked of Solr ---

  test "a keyword search asks for highlights in the text fields, as tagged and HTML-encoded text" do
    params = SearchHighlighting.parameters(state(q: "skull"))

    assert_equal true, params["hl"]
    assert_equal "unified", params["hl.method"]
    assert_equal SearchHighlighting::FIELDS.keys.join(","), params["hl.fl"]
    assert_equal "<mark>", params["hl.tag.pre"]
    assert_equal "</mark>", params["hl.tag.post"]
    assert_equal "html", params["hl.encoder"]
    assert_nil params["hl.q"]
  end

  test "no search words, no highlighting (a browse by filter)" do
    assert_empty SearchHighlighting.parameters(state(f: { collection_ssim: [ "Grainger Museum" ] }))
    assert_empty SearchHighlighting.parameters(state({}))
  end

  test "a search in one field highlights that field only" do
    params = SearchHighlighting.parameters(state(q: "grainger", search_field: "creator"))

    assert_equal "creator_tsim", params["hl.fl"]
    assert_equal true, params["hl.requireFieldMatch"]
  end

  test "Advanced search rows are given to the highlighter as their own queries, the words as parameters of their own" do
    clause = { "0" => { field: "title", op: "must", query: "skull" }, "1" => { field: "creator", op: "should", query: "melanesian \"x\" }{!" },
               "2" => { field: "all_fields", op: "must_not", query: "bone" }, "3" => { field: "title", op: "must", query: "  " } }
    params = SearchHighlighting.parameters(state(clause: clause))

    assert_equal "{!bool should=$hlq0 should=$hlq1}", params["hl.q"]
    assert_equal "{!edismax qf='title_tsim alternative_title_tsim' mm=0 v=$hlt0}", params["hlq0"]
    assert_equal "{!edismax qf='creator_tsim' mm=0 v=$hlt1}", params["hlq1"]
    assert_equal "skull", params["hlt0"]
    assert_equal "melanesian \"x\" }{!", params["hlt1"], "the words travel as a parameter, never inside the query text"
    assert_nil params["hlq2"], "a Does not contain row is not highlighted"
    assert_equal "title_tsim,alternative_title_tsim,creator_tsim", params["hl.fl"]
    assert_equal true, params["hl.requireFieldMatch"]
  end

  test "a request for no records (counts, facets) is not given highlighting parameters" do
    builder = SearchBuilder.new(CatalogController.new).with(q: "skull")
    with_rows = { rows: 40 }
    without_rows = { rows: 0 }
    builder.add_highlighting_to_solr(with_rows)
    builder.add_highlighting_to_solr(without_rows)

    assert with_rows.key?("hl")
    assert_not without_rows.key?("hl")
  end

  # --- Reading the answer ---

  test "the fields matched are listed in the order of the Matched in line, with their names" do
    found = match("description_tsim" => [ "a <mark>skull</mark>" ], "title_tsim" => [ "<mark>Skull</mark>" ], "creator_tsim" => [ "x <mark>skull</mark>" ])

    assert_equal %w[title_tsim creator_tsim description_tsim], found.fields
    assert_equal [ "Title", "Creator", "Description" ], found.labels
    assert found.matched_in?("title_tsim")
    assert_not found.matched_in?("subject_tsim")
  end

  test "fields that are not listed, or have no snippet, are ignored (internal and access notes are never named)" do
    found = match("source_reference_tsim" => [ "Community Restricted <mark>x</mark>" ], "restrictions_tsi" => [ "<mark>sensitive</mark>" ], "title_tsim" => [])

    assert_not found.any?
    assert_empty found.fields
  end

  test "the marked words are collected as they are written in the record, longest first, decoded" do
    found = match("title_tsim" => [ "<mark>Human skull</mark> &amp; <mark>bone</mark>" ], "description_tsim" => [ "the <mark>skull</mark>, <mark>Skull</mark>" ])

    assert_equal [ "Human skull", "skull", "bone" ], found.terms
  end

  test "mark wraps those words in the card's own text, whole words only, and escapes everything else" do
    found = match("title_tsim" => [ "<mark>skull</mark>" ])

    assert_equal "Cat <mark>skull</mark> &amp; &lt;b&gt;bones&lt;/b&gt;", found.mark("Cat skull & <b>bones</b>")
    assert_equal "Skulls and <mark>SKULL</mark>", found.mark("Skulls and SKULL")
    assert_predicate found.mark("x"), :html_safe?
  end

  test "mark leaves text with no matched words as plain escaped text" do
    assert_equal "&lt;i&gt;a&lt;/i&gt;", match({}).mark("<i>a</i>")
  end

  test "a phrase is marked as one piece, and wildcard or accented matches are marked as the record writes them" do
    assert_equal "Disarticulated <mark>human skull</mark>", match("title_tsim" => [ "<mark>human skull</mark>" ]).mark("Disarticulated human skull")
    assert_equal "<mark>Café</mark> au lait", match("title_tsim" => [ "<mark>Café</mark>" ]).mark("Café au lait")
  end

  test "the snippet keeps Solr's <mark> tags and nothing else: record text can never become markup" do
    hostile = "<script>alert(1)</script> &lt;img src=x onerror=alert(1)&gt; <mark>skull</mark> <b onclick=x>b</b>"
    snippet = match("description_tsim" => [ hostile ]).snippet

    assert_includes snippet, "<mark>skull</mark>"
    assert_no_match(/<script|<img|<b/i, snippet)
    assert_equal 1, snippet.scan("<mark>").size
    assert_predicate snippet, :html_safe?
  end

  test "the snippet comes from a field the card does not show: description before subject" do
    found = match("title_tsim" => [ "<mark>a</mark>" ], "subject_tsim" => [ "<mark>s</mark>" ], "description_tsim" => [ "<mark>d</mark>" ])

    assert_equal "<mark>d</mark>", found.snippet
    assert_nil match("title_tsim" => [ "<mark>a</mark>" ], "creator_tsim" => [ "<mark>c</mark>" ]).snippet
  end

  test "a record's match is read from its response, and is nil when the response has no highlighting" do
    response = Blacklight::Solr::Response.new({ "response" => { "docs" => [ { "id" => "a" }, { "id" => "b" } ] },
                                                "highlighting" => { "a" => { "title_tsim" => [ "<mark>x</mark>" ] }, "b" => {} } }, {}, blacklight_config: CatalogController.blacklight_config)
    bare = Blacklight::Solr::Response.new({ "response" => { "docs" => [ { "id" => "a" } ] } }, {}, blacklight_config: CatalogController.blacklight_config)

    assert_equal %w[title_tsim], SearchHighlighting.for(response.documents.first).fields
    assert_not SearchHighlighting.for(response.documents.last).any?, "matched, but in no field the site names"
    assert_nil SearchHighlighting.for(bare.documents.first)
    assert_nil SearchHighlighting.for(SolrDocument.new("id" => "a"))
  end

  # --- Proof that the parameters change nothing about matching or order ---

  test "asking for highlights returns the same records, in the same order, with the same scores (against the core)" do
    needs_solr
    builder = SearchBuilder.new(CatalogController.new)
    queries = [ { q: "skull" }, { q: "\"human skull\"" }, { q: "ske*" }, { q: "skull AND bone" }, { q: "skull -bone" },
                { q: "anatomy", search_field: "title" },
                { clause: { "0" => { field: "title", op: "must", query: "skull" }, "1" => { field: "creator", op: "must", query: "melanesian" } } } ]

    queries.each do |query|
      with = builder.with(query).to_h
      without = with.reject { |key, _| key.to_s.start_with?("hl", "hlq", "hlt") }
      assert_not_equal with.keys, without.keys, "the test must really remove the highlighting parameters for #{query}"
      a = Blacklight.default_index.search(params: with)
      b = Blacklight.default_index.search(params: without)

      assert_equal b.documents.map(&:id), a.documents.map(&:id), query.inspect
      assert_equal b.total, a.total, query.inspect
      assert_equal b.documents.map { |doc| doc["score"] }, a.documents.map { |doc| doc["score"] }, query.inspect
      assert_not_nil a["highlighting"], "highlighting is returned for #{query.inspect}"
    end
  end

  test "Advanced search rows, quoted phrases and wildcards find marks in the records (against the core)" do
    needs_solr
    builder = SearchBuilder.new(CatalogController.new)
    advanced = builder.with(clause: { "0" => { field: "title", op: "must", query: "skull" }, "1" => { field: "creator", op: "must", query: "melanesian" } }).to_h
    phrase = builder.with(q: "\"human skull\"").to_h
    wildcard = builder.with(q: "ske*").to_h

    entry = Blacklight.default_index.search(params: advanced)["highlighting"].values.first
    assert_includes entry.keys, "title_tsim"
    assert_includes entry.keys, "creator_tsim"
    assert_includes Blacklight.default_index.search(params: phrase)["highlighting"].values.flat_map(&:values).flatten.join, "<mark>Human skull</mark>"
    assert_match(/<mark>Sketch/i, Blacklight.default_index.search(params: wildcard)["highlighting"].values.flat_map(&:values).flatten.join)
  end
end
