# A visitor's request for access to one record (CCS-69): to view a record that is not licensed, or to download one that
# is view-only. Made without a login, so it holds the requester's own details; staff action it from
# `bin/rails access_requests:export` until an admin screen exists. document_title is a copy of the record's title
# taken when the request was made, so the request still reads right if the record changes.
class CreateAccessRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :access_requests do |t|
      t.string :document_id, null: false
      t.string :document_title, null: false
      t.string :request_type, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.string :organisation
      t.text :purpose, null: false
      t.string :status, null: false, default: "pending"
      t.timestamps
    end
    add_index :access_requests, :status
    add_index :access_requests, :document_id
  end
end
