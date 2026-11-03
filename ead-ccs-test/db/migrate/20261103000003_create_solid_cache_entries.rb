# The table of the shared cache store (CACHE_STORE=solid_cache; lib/cache_store_config.rb, CCS-144), in the primary database so that
# a deployment needs no second one. Unused (and empty) while the cache is in memory. Same columns as the solid_cache gem's own schema.
class CreateSolidCacheEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :solid_cache_entries do |t|
      t.binary :key, limit: 1024, null: false
      t.binary :value, limit: 536_870_912, null: false
      t.datetime :created_at, null: false
      t.bigint :key_hash, null: false
      t.integer :byte_size, null: false
      t.index :byte_size
      t.index %i[key_hash byte_size]
      t.index :key_hash, unique: true
    end
  end
end
