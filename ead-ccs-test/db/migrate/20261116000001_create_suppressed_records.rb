# Records taken out of the public site (CCS-112): the record's id, why, when and by whom (free text, as there is no sign-in).
# SuppressedRecord is the model; docs/remove-a-record.md says how staff use it.
class CreateSuppressedRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :suppressed_records do |t|
      t.string :record_id, null: false
      t.text :reason, null: false
      t.datetime :suppressed_at, null: false
      t.string :suppressed_by

      t.timestamps
    end
    add_index :suppressed_records, :record_id, unique: true
  end
end
