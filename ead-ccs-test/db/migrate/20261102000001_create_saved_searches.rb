# A search a visitor chose to keep (CCS-130): the search's parameters copied from their history, so it outlives
# Blacklight's searches table rows and the history's 100-search window. Owned by the guest user (no login).
class CreateSavedSearches < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_searches do |t|
      t.references :user, null: false, index: true
      t.string :name, null: false
      t.jsonb :query_params, null: false, default: {}
      t.timestamps
    end
  end
end
