require "test_helper"
require "nokogiri"

# CCS-56: the Solr configuration in solr/conf. The first tests read the files (no Solr); the last asks a core built from them
# (the CI system job's) how it analyses text, and skips on a core made earlier.
class SolrCjkConfigTest < ActiveSupport::TestCase
  SCHEMA = Nokogiri::XML(File.read(Rails.root.join("solr/conf/schema.xml")))

  test "the CJK type keeps only CJK characters, makes the widths the same and indexes characters and pairs" do
    type = SCHEMA.at_xpath("//fieldType[@name='text_cjk']")
    classes = type.xpath(".//*[@class]").map { |element| element["class"].delete_prefix("solr.") }

    assert_equal %w[PatternReplaceCharFilterFactory StandardTokenizerFactory CJKWidthFilterFactory LowerCaseFilterFactory CJKBigramFilterFactory], classes
    assert_equal "true", type.at_xpath(".//filter[@class='solr.CJKBigramFilterFactory']")["outputUnigrams"]
  end

  test "the CJK fields are filled from the title, creator, subject, description and every text field; the English fields are untouched" do
    fields = SCHEMA.xpath("//field[@type='text_cjk']").map { |field| field["name"] }
    copies = SCHEMA.xpath("//copyField").map { |copy| [ copy["source"], copy["dest"] ] }

    assert_equal %w[all_text_cjk creator_cjk description_cjk subject_cjk title_cjk], fields.sort
    [ %w[title_tsim title_cjk], %w[creator_tsim creator_cjk], %w[subject_tsim subject_cjk], %w[description_tsim description_cjk], %w[*_tsim all_text_cjk] ].each do |pair|
      assert_includes copies, pair
    end
    assert_equal "text", SCHEMA.at_xpath("//field[@name='title_tsim']")["type"]
    assert_includes copies, %w[*_tsim all_text_timv]
  end

  test "the handler names the CJK fields in the qf of the default search, title, creator, subject and description" do
    config = File.read(Rails.root.join("solr/conf/solrconfig.xml"))

    %w[all_text_cjk title_cjk creator_cjk subject_cjk description_cjk cjk_qf description_qf].each { |name| assert_includes config, name }
  end

  def analyse(text)
    response = Blacklight.default_index.connection.get("analysis/field", params: { "analysis.fieldtype": "text_cjk", "analysis.fieldvalue": text, wt: "json" })
    response.dig("analysis", "field_types", "text_cjk", "index").last.map { |token| token["text"] }
  rescue StandardError
    skip "needs a Solr core built from solr/conf (text_cjk) at SOLR_URL"
  end

  test "a core built from it indexes characters and pairs, and drops everything else" do
    tokens = analyse("Violin 山水畫")

    assert_equal %w[山 山水 水 水畫 畫].sort, tokens.sort
    assert_not_includes tokens, "violin"
    assert_includes analyse("ｶﾀｶﾅ"), "カタ"
    assert_includes analyse("달항아리"), "항아"
  end
end
