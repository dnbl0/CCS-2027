# frozen_string_literal: true

# The records a visitor has ticked on the results pages, to look at together, cite or download (CCS-40). Kept in the session
# cookie only, as record ids in the order they were chosen: nothing is stored on the server, so a visitor's selection is
# invisible to every other visitor and needs no login. A cookie holds about 4 KB, shared with the rest of the session (the
# guest's id, Sensitivity::Choices, flash), so a selection holds at most MAX records; ids only, never titles.
class Selection
  KEY = :selected_records
  MAX = 50
  ID_LIMIT = 200 # as RecordLookup: a longer id is not a record's

  # session: the request's session
  def initialize(session)
    @session = session
  end

  # The chosen ids, first chosen first. Anything in the cookie that is not a plausible id is ignored.
  def ids
    stored = @session[KEY]
    return [] unless stored.is_a?(Array)

    stored.select { |id| id.is_a?(String) && id.present? && id.length <= ID_LIMIT }.uniq.first(MAX)
  end

  def count = ids.size

  def include?(id) = ids.include?(id.to_s)

  def full? = count >= MAX

  def empty? = ids.empty?

  # Adds ids after the ones already chosen, skipping any already there, until the selection is full. Returns the ids that did
  # not fit (nothing is dropped silently: the caller says so).
  def add(new_ids)
    current = ids
    room = MAX - current.size
    fresh = clean(new_ids) - current
    @session[KEY] = current + fresh.first(room)
    fresh.drop(room)
  end

  def remove(old_ids)
    @session[KEY] = ids - clean(old_ids)
  end

  # Within `scope` (the records the form showed), exactly `chosen` are selected: the others are taken out, the new ones are
  # added in the order given. The rest of the selection is left alone. Returns the ids that did not fit.
  def sync(scope:, chosen:)
    chosen = clean(chosen) & clean(scope)
    remove(clean(scope) - chosen)
    add(chosen)
  end

  def clear
    @session.delete(KEY)
  end

  # Keeps only the ids given (those still in the index), in the selection's order
  def keep_only(existing_ids)
    @session[KEY] = ids & clean(existing_ids)
  end

  # 1-based place of the record in the selection, or nil
  def position(id)
    index = ids.index(id.to_s)
    index && index + 1
  end

  def previous_id(id)
    index = ids.index(id.to_s)
    index&.positive? ? ids[index - 1] : nil
  end

  def next_id(id)
    index = ids.index(id.to_s)
    index ? ids[index + 1] : nil
  end

  private

  def clean(list)
    Array(list).map(&:to_s).select { |id| id.present? && id.length <= ID_LIMIT }.uniq
  end
end
