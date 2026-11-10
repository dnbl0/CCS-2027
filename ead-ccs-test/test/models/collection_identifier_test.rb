require "test_helper"

# CCS-22: CCS has no global ID, so a record is identified by its collection and its collection's own number (accession
# number; the IRN is in the UoM ID, "emu-umc-<IRN>").
class CollectionIdentifierTest < ActiveSupport::TestCase
  def identifier(fields = {})
    CollectionIdentifier.new(SolrDocument.new({ "id" => "emu-400329", "collection_ssim" => [ "Grainger Museum Collection" ],
                                            "accession_number_ssim" => [ "00.0001" ] }.merge(fields)))
  end

  test "the UoM ID names the EMu system and keeps the IRN" do
    assert_equal "emu-umc-400329", identifier.uom_id
    assert_equal "vernon-77", CollectionIdentifier.new(SolrDocument.new("id" => "vernon-77")).uom_id
  end

  test "the statement is the collection, the accession number and the UoM ID" do
    assert_equal "Grainger Museum Collection, accession number 00.0001, UoM ID emu-umc-400329", identifier.to_s
  end

  test "a part the record does not have is left out" do
    assert_equal "Grainger Museum Collection, UoM ID emu-umc-400329", identifier("accession_number_ssim" => nil).to_s
    assert_equal "UoM ID emu-umc-400329", identifier("accession_number_ssim" => nil, "collection_ssim" => nil).to_s
  end
end
