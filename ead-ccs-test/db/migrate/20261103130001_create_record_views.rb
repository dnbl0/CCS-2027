# Trending (docs/similar-and-trending.md): how many times each record page was viewed on each day. Counts only: a record id, a
# date and a number. No visitor, session, cookie, IP address or user agent is stored, so no row can be traced to a person.
class CreateRecordViews < ActiveRecord::Migration[8.1]
  def change
    create_table :record_views do |t|
      t.string :document_id, null: false
      t.date :day, null: false
      t.integer :views, null: false, default: 0
    end
    add_index :record_views, %i[day document_id], unique: true
    add_index :record_views, :document_id
  end
end
