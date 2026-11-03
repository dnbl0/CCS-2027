# frozen_string_literal: true

require "active_support/core_ext/numeric/bytes"

# Which cache store the app uses, chosen by the CACHE_STORE environment variable (CCS-144). The cache holds the header's collection
# counts, the sitemap's record list and, with RATE_LIMIT_STORE=cache, the rate limit's counts. All of them are rebuilt when missing,
# so losing the cache costs speed, never data.
#   memory       (default) in the process: nothing to install, but each process and instance keeps its own copy and its own counts
#   file         CACHE_PATH, a directory every instance can see (a shared volume): shared, slower, no expiry sweep
#   solid_cache  shared through the database (the solid_cache gem, table solid_cache_entries): the option for several instances
#                with no extra service
#   null         nothing is cached (the header's counts and the sitemap then ask Solr on every request: only for diagnosis)
# A Redis or Memcached store needs a gem the app does not have; add the gem and a branch here.
module CacheStoreConfig
  STORES = %w[memory file solid_cache null].freeze

  # Returns the arguments for config.cache_store. env: ENV, or a Hash in tests.
  def self.build(env)
    case env.fetch("CACHE_STORE", "memory")
    when "memory" then [ :memory_store, { size: (Integer(env.fetch("CACHE_MEMORY_MB", 64), exception: false) || 64).megabytes } ]
    when "file" then [ :file_store, env.fetch("CACHE_PATH", "tmp/cache") ]
    when "solid_cache" then [ :solid_cache_store ]
    when "null" then [ :null_store ]
    else raise ArgumentError, "CACHE_STORE must be one of #{STORES.join(', ')}"
    end
  end
end
