# frozen_string_literal: true

# The records this visitor has opened, newest first, for the "Recently viewed" cards on a record page. Only the ids are kept,
# in the session cookie (as Sensitivity::Choices keeps its choices): nothing is stored on the server, no one else can see it,
# and clearing cookies or "Delete my data" removes it.
class RecentlyViewed
  KEY = :recently_viewed
  SHOWN = 4 # cards in the record page's section
  MAX = 12 # the cookie holds about 4 KB, shared with the rest of the session

  def initialize(session)
    @session = session
  end

  def record(document_id)
    id = document_id.to_s
    return if id.blank?

    @session[KEY] = [ id, *stored.reject { |kept| kept == id } ].first(MAX)
  end

  # The ids, newest first; except: the record being read (it is not "recently viewed" beside itself)
  def ids(except: nil) = stored.reject { |id| id == except.to_s }

  # The `limit` newest records, newest first. Ones no longer in the index are left out; an empty list if Solr cannot answer.
  def documents(except:, limit: SHOWN, connection: nil)
    wanted = ids(except: except).first(limit)
    return [] if wanted.empty?

    found = RecordSummaries.fetch({ fq: "id:(#{wanted.map { |id| RecordSummaries.phrase(id) }.join(' OR ')})", rows: wanted.size }, connection).to_a
    found.index_by { |fields| fields["id"] }.values_at(*wanted).compact.map { |fields| SolrDocument.new(fields) }
  end

  private

  def stored
    value = @session[KEY]
    value.is_a?(Array) ? value.select { |id| id.is_a?(String) && id.present? } : []
  end
end
