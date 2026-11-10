# frozen_string_literal: true

# A replaced image shows without a manual purge (CCS-425). A file in the DAM can be replaced by one with the same name (an
# orientation fix, say); the address a browser or cache already holds would then show the old picture. This gives the address of
# a file this server holds under public/digital-assets a token, "?v=<modified time and size>": replace the file and the token,
# so the address, changes; the next page the visitor loads points at the new one. (StaticCacheControl lets a tokened address be
# cached for a year, and an untokened one only be reused after the server says it is unchanged.)
#
# What it does not do: see docs/media-refresh.md. It reads the file this server holds, so a file replaced in the DAM reaches CCS
# only when the ingest copies it into public/digital-assets; and a file on another host (CCS_MEDIA_BASE_URL, an IIIF image
# server) is left alone, as nothing here can see it change.
#
# Call it only where the record's assets are already allowed to appear (AccessPolicy, Sensitivity): it adds a token to an
# address, it decides nothing.
module AssetVersion
  PREFIX = "/digital-assets/"
  # A file is looked at again after this many seconds, not for every address on every page (a results page has dozens)
  CHECK_EVERY = 10
  PARAM = "v"
  CHECKED = Concurrent::Map.new

  module_function

  # path: "/digital-assets/large/a.jpg" (a nil or blank path gives the same back). root: where public/ is.
  def url(path, root: Rails.public_path, now: Time.now)
    return path unless local?(path)

    base, query = path.split("?", 2)
    token = token_for(base, root, now)
    return path unless token

    "#{base}?#{[ query.presence, "#{PARAM}=#{token}" ].compact.join("&")}"
  end

  # The address without the token, for reading the file it names
  def path(path)
    path&.split("?", 2)&.first
  end

  # Whether a query string carries a token
  def versioned?(query)
    query.to_s.split("&").any? { |pair| pair.match?(/\A#{PARAM}=\h+\z/) }
  end

  def reset! = CHECKED.clear

  def local?(path)
    path.is_a?(String) && path.start_with?(PREFIX) && !path.include?("..") && path.split("?", 2).first.length > PREFIX.length
  end

  def token_for(base, root, now)
    key = "#{root}#{base}"
    checked_at, token = CHECKED[key]
    return token if checked_at && now - checked_at < CHECK_EVERY

    token = read(root.join(base.delete_prefix("/")))
    CHECKED[key] = [ now, token ]
    token
  end

  def read(file)
    stat = File.stat(file)
    return unless stat.file?

    format("%x%x", stat.mtime.to_i, stat.size)
  rescue SystemCallError
    nil
  end
end
