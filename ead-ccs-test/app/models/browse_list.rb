# frozen_string_literal: true

# What one browse page shows: its entries (value or period, count, the search it opens), for the chosen letter, or the most
# common ones when no letter is chosen. A letter that is not one of the list's (a hand-edited address) is no letter.
class BrowseList
  Entry = Data.define(:label, :count, :query)

  def initialize(hub, letter: nil, connection: nil)
    @hub = hub
    @connection = connection
    @all = hub.slug == "periods" ? BrowseHubs.period_entries(connection) : BrowseHubs.values(hub, connection)
    @letter = letter.to_s.upcase if !periods? && letters.include?(letter.to_s.upcase)
  end

  attr_reader :hub, :letter

  def available? = !@all.nil?

  def periods? = hub.slug == "periods"

  def letters = @letters ||= available? && !periods? ? BrowseHubs.letters(@all) : []

  def entries
    return [] unless available?

    return @all.map { |label, count, first, last| Entry.new(label, count, BrowseHubs.period_query(first, last)) } if periods?

    chosen = letter ? BrowseHubs.for_letter(@all, letter) : @all.first(BrowseHubs::MOST_RECORDS)
    chosen.map { |value, count| Entry.new(value, count, BrowseHubs.query(hub.field, value)) }
  end

  # "Most records" when no letter is chosen
  def heading = letter ? "Starting with #{letter == BrowseHubs::OTHER_LETTER ? 'a number or sign' : letter}" : (periods? ? "All periods" : "Most records")

  def total = available? ? @all.size : 0
end
