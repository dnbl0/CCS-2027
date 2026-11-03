require "test_helper"

# Ranking and the default query are unchanged: the same request through SearchBuilder as it was before rules (Blacklight's own
# add_adv_search_clauses) and as it is now gives the same Solr parameters, and, against the core, the same ids, order and scores.
class AdvancedRulesRankingTest < ActiveSupport::TestCase
  Baseline = Class.new(SearchBuilder) do
    define_method(:add_adv_search_clauses, Blacklight::Solr::SearchBuilderBehavior.instance_method(:add_adv_search_clauses))
  end

  REQUESTS = [
    { q: "skull" }, { q: "skull bone shell tool basket stone wood" }, { q: "skull OR bone -shell" }, { q: "skull", search_field: "title" },
    { q: "portrait", f: { has_digital_asset: [ "with" ] } }, { q: "skull", f: { has_digital_asset: [ "with" ], free_reuse: [] } },
    { clause: { "0" => { field: "title", query: "skull" } } },
    { op: "should", clause: { "0" => { field: "title", query: "skull" }, "1" => { field: "creator", op: "must_not", query: "ann" } } },
    { clause: { "0" => { field: "all_fields", query: "skull OR bone" } } }
  ].freeze

  def params_for(builder_class, request)
    builder_class.new(CatalogController.new).with(request).to_h.except(:rows)
  end

  test "the Solr parameters of plain and old-style requests are those of Blacklight's own code" do
    REQUESTS.each { |request| assert_equal params_for(Baseline, request), params_for(SearchBuilder, request), request.inspect }
  end

  test "against the core, ids, order and scores are the same" do
    needs_solr
    REQUESTS.each do |request|
      before, after = [ Baseline, SearchBuilder ].map do |klass|
        response = Blacklight.default_index.search(params: klass.new(CatalogController.new).with(request).to_h.merge(rows: 40, fl: "id,score"))
        response.documents.map { |doc| [ doc.id, doc["score"] ] }
      end

      assert_equal before, after, request.inspect
    end
  end
end
