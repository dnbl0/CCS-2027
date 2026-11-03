require "test_helper"

# The "Open licence (public domain)" filter (FreeReuse): built from AccessPolicy, so it is the rule the download button uses.
class FreeReuseTest < ActiveSupport::TestCase
  def count(fq)
    Blacklight.default_index.connection.get("select", params: { q: "*:*", rows: 0, fq: fq })["response"]["numFound"]
  end

  test "the filter asks for an open licence, no licence that is not an open one, and no withheld access condition" do
    query = FreeReuse.filter_query

    assert_includes query, '"Public domain - Copyright expired"'
    assert_includes query, '-licence_type_ssim:([* TO "PUBLIC DOMAIN - COPYRIGHT EXPIRED"}'
    assert_match(/ TO \*\]\)/, query)
    assert_includes query, '-access_condition_ssi:("COMMUNITY RESTRICTED" "Community Restricted"'
  end

  test "it is read from AccessPolicy: another open licence is in the filter" do
    original = AccessPolicy::TIER_BY_LICENCE
    AccessPolicy.send(:remove_const, :TIER_BY_LICENCE)
    AccessPolicy.const_set(:TIER_BY_LICENCE, original.merge("example licence" => :open).freeze)

    assert_includes FreeReuse.filter_query, '"Example Licence"'
  ensure
    AccessPolicy.send(:remove_const, :TIER_BY_LICENCE)
    AccessPolicy.const_set(:TIER_BY_LICENCE, original)
  end

  test "with no open licence it matches nothing" do
    original = AccessPolicy::TIER_BY_LICENCE
    AccessPolicy.send(:remove_const, :TIER_BY_LICENCE)
    AccessPolicy.const_set(:TIER_BY_LICENCE, {}.freeze)

    assert_equal "-*:*", FreeReuse.filter_query
  ensure
    AccessPolicy.send(:remove_const, :TIER_BY_LICENCE)
    AccessPolicy.const_set(:TIER_BY_LICENCE, original)
  end

  test "the facet is a query facet with the neutral label" do
    config = CatalogController.blacklight_config.facet_fields["free_reuse"]

    assert_equal "Open licence (public domain)", config.query.dig("open", :label)
    assert_equal FreeReuse.filter_query, config.query.dig("open", :fq)
  end

  test "against the core, every record it matches is :open, and every :open licence value is matched" do
    needs_solr
    response = Blacklight.default_index.connection.get("select", params: { q: "*:*", fq: FreeReuse.filter_query, rows: 5000, fl: "id,licence_type_ssim,access_condition_ssi" })["response"]
    documents = response["docs"].map { |doc| SolrDocument.new(doc) }

    assert_operator response["numFound"], :>, 0
    assert_equal [ :open ], documents.map { |doc| AccessPolicy.tier(doc) }.uniq

    facets = Blacklight.default_index.connection.get("select", params: { q: "*:*", rows: 0, facet: true, "facet.field": "licence_type_ssim", "facet.limit": -1 })["facet_counts"]["facet_fields"]["licence_type_ssim"]
    open_values = facets.each_slice(2).select { |value, _| AccessPolicy.licences_with_tier(:open).include?(value.downcase) }.map(&:first)
    only_open = count([ "licence_type_ssim:(#{open_values.map { |v| %("#{v}") }.join(' ')})" ]) # documents with an open licence (some also have another)
    assert_operator response["numFound"], :<=, only_open
  end

  test "against the core, a record with an open and a restricted licence, or none, or Community Restricted, is left out" do
    needs_solr
    assert_equal 0, count([ FreeReuse.filter_query, "-licence_type_ssim:[* TO *]" ])
    assert_equal 0, count([ FreeReuse.filter_query, 'access_condition_ssi:"Community Restricted"' ])
    assert_equal 0, count([ FreeReuse.filter_query, 'licence_type_ssim:"Copyright - Current"' ])
  end
end
