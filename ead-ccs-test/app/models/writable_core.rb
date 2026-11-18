# frozen_string_literal: true

# The Solr core of its own that the colour and clean-up tasks read and write (DAM_SOLR_URL, as the DAM sync: docs/dam-sync.md), never
# the shared core. Atomic updates there keep every other stored field.
module WritableCore
  BATCH = 500

  def self.connect
    url = ENV["DAM_SOLR_URL"].presence
    raise Dam::Error, "DAM_SOLR_URL is not set: these tasks write only to a core of their own (docs/colour-and-clean-up.md)" unless url

    RSolr.connect(url: url)
  end

  # Yields every record matching the filters, BATCH at a time (cursor paging, so the order is stable while it is read)
  def self.each_batch(solr, fl:, fq: [], q: "*:*")
    cursor = "*"
    loop do
      response = solr.get("select", params: { q: q, fq: fq, fl: fl, sort: "id asc", rows: BATCH, cursorMark: cursor, wt: "json" })
      docs = response.dig("response", "docs") || []
      yield docs if docs.any?
      break if docs.empty? || response["nextCursorMark"] == cursor

      cursor = response["nextCursorMark"]
    end
  end

  # Atomic "set" updates ({ "id" => ..., field => value }; nil removes the field), sent 100 at a time. Returns how many were sent.
  def self.update(solr, changes)
    changes.each_slice(100) { |slice| solr.add(slice.map { |change| change.to_h { |key, value| [ key, key == "id" ? value : { "set" => value } ] } }) }
    solr.commit if changes.any?
    changes.size
  end
end
