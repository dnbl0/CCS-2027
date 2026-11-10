# The record's identifier as it was when the request was made (CCS-22): its collection, accession number and UoM ID
# (RecordIdentifier), so staff can find the object a reuse request is about without looking the Solr id up.
class AddDocumentIdentifierToAccessRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :access_requests, :document_identifier, :string
  end
end
