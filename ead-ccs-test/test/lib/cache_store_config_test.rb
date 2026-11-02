require "test_helper"

class CacheStoreConfigTest < ActiveSupport::TestCase
  test "memory is the default, with a size" do
    store, options = CacheStoreConfig.build({})

    assert_equal :memory_store, store
    assert_equal 64.megabytes, options[:size]
  end

  test "each store is chosen by name" do
    assert_equal [ :memory_store, { size: 8.megabytes } ], CacheStoreConfig.build("CACHE_MEMORY_MB" => "8")
    assert_equal [ :file_store, "/mnt/shared/cache" ], CacheStoreConfig.build("CACHE_STORE" => "file", "CACHE_PATH" => "/mnt/shared/cache")
    assert_equal [ :solid_cache_store ], CacheStoreConfig.build("CACHE_STORE" => "solid_cache")
    assert_equal [ :null_store ], CacheStoreConfig.build("CACHE_STORE" => "null")
  end

  test "an unknown name stops the boot with the choices" do
    error = assert_raises(ArgumentError) { CacheStoreConfig.build("CACHE_STORE" => "redis") }
    assert_match(/memory, file, solid_cache, null/, error.message)
  end

  test "the solid_cache table exists, so the shared option works after a migration" do
    assert ActiveRecord::Base.connection.table_exists?("solid_cache_entries")
  end
end
