# frozen_string_literal: true

# How a record is identified (CCS-22). CCS has no global ID: a record is identified by its collection and the number the
# collection gives it (the accession number), and the UoM ID carries the IRN ("emu-umc-400329" is IRN 400329 in
# Museums & Collections' EMu). This is the one place the three are put together, so the record page, the citations, the
# metadata CSV, the contact email and the access request form all say the same thing.
#
#   CollectionIdentifier.new(document).to_s  # => "Grainger Museum Collection, accession number 00.0001, UoM ID emu-umc-400329"
class CollectionIdentifier
  # The University has three EMu systems (emu-umc, emu-feit, emu-prints), so the UoM ID names which one. Every EMu record
  # here comes from Museums & Collections' (emu-umc). The record's URL keeps its Solr id (emu-400329).
  UOM_ID_PREFIXES = { "emu-" => "emu-umc-" }.freeze

  def self.uom_id(solr_id)
    id = solr_id.to_s
    prefix, uom_prefix = UOM_ID_PREFIXES.find { |solr_prefix, _| id.start_with?(solr_prefix) }
    prefix ? id.sub(prefix, uom_prefix) : id
  end

  def initialize(document)
    @document = document
  end

  def uom_id = self.class.uom_id(@document.id)
  def collection = Array(@document["collection_ssim"]).first.to_s.squish.presence
  def accession = Array(@document["accession_number_ssim"]).first.to_s.squish.presence

  # The collection, the accession number and the UoM ID, as one line that can be quoted; a part the record lacks is left out
  def to_s = [ collection, (accession && "accession number #{accession}"), "UoM ID #{uom_id}" ].compact.join(", ")
end
