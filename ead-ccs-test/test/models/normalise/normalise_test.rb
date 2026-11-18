require "test_helper"
require_relative "../../support/colour_fakes"

# rake index:normalise (Normalise::*): the Materials / Medium and Nationality filters' terms
class NormaliseTest < ActiveSupport::TestCase
  test "materials are split on commas, semicolons, 'and' and 'on', trimmed, lower-cased, with stop words out and synonyms applied" do
    assert_equal %w[paper ink], Normalise::Materials.terms([ "paper, ink" ])
    assert_equal %w[oil canvas], Normalise::Materials.terms([ "Oil on canvas" ])
    assert_equal [ "watercolour", "pencil", "paper" ], Normalise::Materials.terms([ "Water colour and pencil; paper.", "PAPER" ])
    assert_equal [ "oil", "board" ], Normalise::Materials.terms([ "oils on board", "unknown" ])
    assert_empty Normalise::Materials.terms([ nil, "", " , " ])
  end

  test "nationalities come from the list, in the order the text names them; text naming none gives none" do
    assert_equal %w[Australian], Normalise::Nationalities.terms("Australian composer and pianist")
    assert_equal %w[Swedish American], Normalise::Nationalities.terms("Swedish - American artist")
    assert_equal %w[German Australian], Normalise::Nationalities.terms("Born Germany. Lived and worked in Australia")
    assert_equal [ "South African", "British" ], Normalise::Nationalities.terms("South African-born, United Kingdom based")
    assert_equal [ "New Zealander" ], Normalise::Nationalities.terms("new zealand painter")
    assert_empty Normalise::Nationalities.terms("Painter and printmaker")
    assert_empty Normalise::Nationalities.terms("Frenchay"), "whole words only"
  end

  test "the terms are written as atomic updates for changed records only; unmatched nationalities are reported" do
    csv = Rails.root.join("tmp/test-nationality-#{Process.pid}.csv")
    current = { "material_term_ssim" => %w[paper], "nationality_term_ssim" => nil }
    core = FakeWritableCore.new([
      { id: "a", material_ssim: [ "oil on canvas" ], nationality_ssim: [ "Swedish - American artist" ] },
      { id: "same", material_ssim: [ "paper" ], normalise_digest_ssi: Digest::SHA256.hexdigest(current.to_json) },
      { id: "odd", nationality_ssim: [ "Painter" ] }
    ])
    report = Normalise::IndexWriter.new(solr: core, unparsed_csv: csv).write

    assert_equal [ 3, 1 ], [ report.seen, report.updated ], "odd has no terms, and had none: nothing to send"
    a = core.added.find { |doc| doc["id"] == "a" }
    assert_equal({ "set" => %w[oil canvas] }, a["material_term_ssim"])
    assert_equal({ "set" => %w[Swedish American] }, a["nationality_term_ssim"])
    assert_equal %w[a], core.added.map { |doc| doc["id"] }
    assert_equal({ "Painter" => 1 }, report.unparsed)
    assert_includes File.read(csv), "Painter,1"
    assert_match(/1 nationality values name no nationality/, report.to_s)
  ensure
    FileUtils.rm_f(csv)
  end

  test "the Materials / Medium and Nationality filters read the terms when the core has them, else the source fields" do
    assert_equal "material_ssim", NormalisedTerms.field_for("material_ssim")
    NormalisedTerms.force("material_term_ssim" => true)
    assert_equal "material_term_ssim", NormalisedTerms.field_for("material_ssim")
    assert_equal "nationality_ssim", NormalisedTerms.field_for("nationality_ssim")

    config = Blacklight::Configuration.new
    CatalogConfig::Facets.apply(config)
    assert config.facet_fields.key?("material_term_ssim")
    assert_not config.facet_fields.key?("material_ssim")
    assert_equal "Materials / Medium", config.facet_fields["material_term_ssim"].label
  ensure
    NormalisedTerms.force(nil)
  end
end
