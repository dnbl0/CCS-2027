# frozen_string_literal: true

require "zlib"

# Finishes the precompiled assets in public/assets for production (run after assets:precompile, see lib/tasks/asset_bundle.rake).
#
# 1. Propshaft leaves the @import lines of the CSS manifests (application.css, stock_blacklight.css) as they are, with each file's
#    fingerprinted address, so a browser fetches the manifest and then about fifty more stylesheets, each one a request that blocks
#    the first paint. flatten_css puts the imported files into the manifest itself, in the same order, so it is one request.
#    Every address inside is already fingerprinted and absolute (/assets/name-digest.ext), so the content is unchanged. The manifest
#    keeps its file name: the name changes whenever any imported file changes, so a cached copy is never stale.
# 2. gzip_assets writes a .gz beside each text asset. ActionDispatch::Static serves it to browsers that accept gzip, with no
#    compression work per request.
module AssetBundle
  IMPORT = %r{^@import url\(["']?/assets/(?<path>[^"')]+)["']?\);[ \t]*\n?}
  GZIP_TYPES = %w[.css .js .svg .json .txt .map].freeze
  GZIP_MIN_BYTES = 1024

  module_function

  def run(dir)
    flatten_css(dir)
    gzip_assets(dir)
  end

  # Returns the CSS with every fingerprinted @import url("/assets/...") replaced by that file's own (flattened) content
  def flatten(css, dir, seen = [])
    css.gsub(IMPORT) do
      path = Regexp.last_match[:path]
      file = File.join(dir, path)
      next "" if seen.include?(path) # the second import of a file repeats rules already in place
      next Regexp.last_match[0] unless File.file?(file)

      flatten(File.read(file), dir, seen << path).rstrip + "\n"
    end
  end

  # Rewrites each stylesheet that has fingerprinted @imports; returns the file names rewritten
  def flatten_css(dir)
    Dir.glob(File.join(dir, "**/*.css")).filter_map do |file|
      css = File.read(file)
      next unless css.match?(IMPORT)

      File.write(file, flatten(css, dir))
      file
    end
  end

  # Returns the .gz files written (only where gzip makes the file smaller)
  def gzip_assets(dir)
    Dir.glob(File.join(dir, "**/*")).filter_map do |file|
      next unless GZIP_TYPES.include?(File.extname(file)) && File.file?(file) && File.size(file) >= GZIP_MIN_BYTES

      data = File.binread(file)
      packed = Zlib.gzip(data, level: Zlib::BEST_COMPRESSION)
      next unless packed.bytesize < data.bytesize

      File.binwrite("#{file}.gz", packed)
      "#{file}.gz"
    end
  end
end
