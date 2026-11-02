# Named lists (CCS-389): a visitor groups records into lists of their own, owned by the guest user (no login).
class CreateLists < ActiveRecord::Migration[8.1]
  def change
    create_table :lists do |t|
      t.references :user, null: false, index: true
      t.string :name, null: false
      t.timestamps
    end
    add_index :lists, "user_id, lower(name)", unique: true, name: "index_lists_on_user_id_and_lower_name"

    create_table :list_items do |t|
      t.references :list, null: false, index: true
      t.string :document_id, null: false
      t.timestamps
    end
    add_index :list_items, %i[list_id document_id], unique: true
  end
end
