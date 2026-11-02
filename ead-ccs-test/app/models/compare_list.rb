# frozen_string_literal: true

# The records a visitor has put in the comparison (CCS-58), kept in the session cookie only: ids, at most MAX, in the order added.
# Like Sensitivity::Choices it is not an access decision. It says what the visitor asked for; whether a record's images may be
# shown is decided each time the comparison is drawn (RecordMedia), so a record that has since been withheld simply drops out.
class CompareList
  KEY = :compare_ids
  MAX = 4
  MAX_ID_LENGTH = 200

  def initialize(session)
    @session = session
  end

  def ids
    stored = @session[KEY]
    stored.is_a?(Array) ? stored.select { |id| id.is_a?(String) && id.present? && id.length <= MAX_ID_LENGTH }.uniq.first(MAX) : []
  end

  def full? = ids.size >= MAX
  def include?(id) = ids.include?(id.to_s)

  # false when the list is full; adding a record already in it changes nothing
  def add(id)
    id = id.to_s
    return true if include?(id)
    return false if full?

    @session[KEY] = ids + [ id ]
    true
  end

  def remove(id) = @session[KEY] = ids - [ id.to_s ]
  def replace(new_ids) = @session[KEY] = new_ids.map(&:to_s).uniq.first(MAX)
  def clear = @session.delete(KEY)
end
