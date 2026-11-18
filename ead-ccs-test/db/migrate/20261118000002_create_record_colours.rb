# The colours of the records' thumbnails (rake colour:extract, Colour::Extractor) and, for each record, the records whose colours
# are closest (rake colour:neighbours, Colour::Neighbours): what the colour browse page and "Looks similar" are made from.
class CreateRecordColours < ActiveRecord::Migration[8.1]
  def change
    create_table :record_colours do |t|
      t.string :record_id, null: false
      t.string :image_url, null: false
      # [ { "hex" => "#d62828", "share" => 0.62, "name" => "red" }, ... ] biggest first; buckets: the colour names, biggest first
      t.jsonb :palette, null: false, default: []
      t.jsonb :buckets, null: false, default: []
      # 64-box colour histogram { "box" => share } (Colour::Palette#histogram), for the distance between two records
      t.jsonb :histogram, null: false, default: {}
      # Why the image could not be read (the row is tried again on the next run); nil when it was
      t.string :error
      t.datetime :extracted_at, null: false
      t.timestamps
    end
    add_index :record_colours, :record_id, unique: true

    create_table :colour_neighbours do |t|
      t.string :record_id, null: false
      t.jsonb :neighbour_ids, null: false, default: []
      t.datetime :computed_at, null: false
    end
    add_index :colour_neighbours, :record_id, unique: true
  end
end
