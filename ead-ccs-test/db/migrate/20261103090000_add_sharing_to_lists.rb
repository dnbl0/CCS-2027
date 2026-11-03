# Galleries: a list can carry a description and a cover record, and can be shared by an unguessable link (no login, no
# owner shown). The token is nil until the owner shares; revoking sets it back to nil, regenerating replaces it.
class AddSharingToLists < ActiveRecord::Migration[8.1]
  def change
    add_column :lists, :description, :text
    add_column :lists, :cover_document_id, :string
    add_column :lists, :share_token, :string
    add_column :lists, :shared_at, :datetime
    add_index :lists, :share_token, unique: true
  end
end
