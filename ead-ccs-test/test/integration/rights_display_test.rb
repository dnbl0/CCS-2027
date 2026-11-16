require "test_helper"

# Every record page shows its licence and rights statement, or says that none is recorded (CCS-148). The first test needs the
# Solr core: it takes one record of each licence the index holds, and some with none.
class RightsDisplayTest < ActionDispatch::IntegrationTest
  NONE = "No licence or rights statement is recorded for this record"

  def sample_documents
    connection = Blacklight.default_index.connection
    facet = connection.get("select", params: { q: "*:*", rows: 0, facet: true, "facet.field" => "licence_type_ssim", "facet.limit" => 50, wt: "json" })
    licences = facet.dig("facet_counts", "facet_fields", "licence_type_ssim").each_slice(2).map(&:first)
    by_licence = licences.map { |licence| connection.get("select", params: { q: "*:*", fq: "licence_type_ssim:\"#{licence}\"", rows: 1, wt: "json" }).dig("response", "docs", 0) }
    without = connection.get("select", params: { q: "*:*", fq: "-licence_type_ssim:[* TO *]", rows: 5, wt: "json" }).dig("response", "docs")
    (by_licence + without).compact
  end

  test "a record of every licence the index holds, and records with no licence, show their rights or say none is recorded" do
    needs_solr
    documents = sample_documents
    assert_operator documents.size, :>=, 3

    documents.each do |doc|
      get "/catalog/#{ERB::Util.url_encode(doc['id'])}"

      assert_response :success, doc["id"]
      assert_select "aside.record-copyright", 1, doc["id"]
      card = css_select("aside.record-copyright").first.text
      stated = doc["licence_type_ssim"].present? || doc["rights_ssim"].present? || doc["credit_line_tsim"].present?
      if stated
        assert_not_includes card, NONE, doc["id"]
        assert_includes card, Array(doc["licence_type_ssim"]).first.to_s, doc["id"] if doc["licence_type_ssim"].present?
      else
        assert_includes card, NONE, doc["id"]
      end
      assert_select "aside.record-copyright a[href='/help#copyright']", text: "About copyright and terms of use"
    end
  end

  test "records with an ICIP Rights licence carry the cultural protocols notice" do
    needs_solr
    doc = Blacklight.default_index.connection.get("select", params: { q: "*:*", fq: "licence_type_ssim:\"ICIP Rights\"", rows: 1, wt: "json" }).dig("response", "docs", 0)
    skip "no ICIP Rights record in the index" unless doc

    get "/catalog/#{ERB::Util.url_encode(doc['id'])}"

    assert_select "aside.record-cultural-protocols", 1
    assert_select "aside.record-cultural-protocols a[href='/help#indigenous']"
  end
end
