# The Nexus DAM's (Acquia DAM) assets, one row per asset, kept by Dam::Sync (rake dam:sync). The index is written from
# here (Dam::SolrWriter), so a record's media can be rebuilt without asking the DAM again.
class CreateDamAssets < ActiveRecord::Migration[8.1]
  def change
    create_table :dam_assets do |t|
      t.string :dam_id, null: false
      t.string :accession_number
      t.string :collection
      t.string :filename
      t.string :format_type
      t.string :licence
      t.string :advisory
      t.text :terms_of_use
      t.string :producer
      t.integer :display_sequence
      # The DAM's embed links (they do not expire): { "thumbnail" => ..., "large" => ..., "original" => ... }
      t.jsonb :urls, null: false, default: {}
      t.datetime :dam_updated_at
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :dam_assets, :dam_id, unique: true
    add_index :dam_assets, :accession_number

    # One row per sync run. A full run reads the DAM in date windows (last edit date) and records the end of the last
    # window it finished (checkpoint), so a run that stopped resumes there; a DAM scroll itself expires, so it cannot be resumed.
    create_table :dam_sync_runs do |t|
      t.string :kind, null: false
      t.string :status, null: false, default: "running"
      t.datetime :updated_since
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.datetime :checkpoint
      t.integer :seen, null: false, default: 0
      t.integer :total
      t.text :error
      t.timestamps
    end
    add_index :dam_sync_runs, [ :kind, :status, :started_at ]
  end
end
