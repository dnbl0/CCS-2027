# frozen_string_literal: true

# What one browse page shows: its entries (value or period, count, the search it opens, and the page of its own when it has one), for
# the chosen letter or the words typed in the filter box, or the most common ones when neither is chosen. A letter that is not one of
# the list's (a hand-edited address) is no letter. A long list is paged (PAGE_SIZE).
#
# Makers, places and subjects come grouped by spelling (Browse::Index) and each has an entity page (BrowseEntitiesController); the
# periods have a page each (Browse::Periods); object types open the search.
class BrowseList
  Entry = Data.define(:label, :count, :query, :path)
  PAGE_SIZE = 120

  def initialize(hub, letter: nil, filter: nil, page: nil, connection: nil)
    @hub = hub
    @connection = connection
    @kind = Browse::Kind.find(hub.slug)
    @all = periods? ? BrowseHubs.period_entries(connection) : values
    @letter = letter.to_s.upcase if !periods? && letters.include?(letter.to_s.upcase)
    @filter = filter.to_s.squish.first(80).presence unless periods?
    @page = page.to_i
  end

  attr_reader :hub, :letter, :filter

  def available? = !@all.nil?

  def periods? = hub.slug == "periods"

  def letters = @letters ||= available? && !periods? ? BrowseHubs.letters(@all) : []

  # Everything the page lists, before paging: [[value, count], ...] or the periods
  def chosen
    return @all.to_a if periods?

    list = @all
    list = list.select { |value, _count| Browse::Slug.fold(value).include?(Browse::Slug.fold(filter)) } if filter
    return BrowseHubs.for_letter(list, letter) if letter

    filter ? list : list.first(BrowseHubs::MOST_RECORDS)
  end

  def paged? = (letter || filter) && chosen.size > PAGE_SIZE

  def pages = [ (chosen.size.to_f / PAGE_SIZE).ceil, 1 ].max

  def page = paged? ? @page.clamp(1, pages) : 1

  def entries
    return [] unless available?

    return @all.map { |label, count, first, last| Entry.new(label, count, BrowseHubs.period_query(first, last), Browse::Periods.for_span(first, last)&.path) } if periods?

    shown = paged? ? chosen.slice((page - 1) * PAGE_SIZE, PAGE_SIZE) : chosen
    shown.map { |value, count| Entry.new(value, count, BrowseHubs.query(hub.field, value), @kind && Browse.path_for(@kind.key, value)) }
  end

  # "Most records" when no letter is chosen
  def heading
    return "Matching “#{filter}”" if filter && !letter
    return "Starting with #{letter == BrowseHubs::OTHER_LETTER ? 'a number or sign' : letter}" if letter

    periods? ? "All periods" : "Most records"
  end

  def total = available? ? @all.size : 0

  private

  # Makers, places and subjects are grouped (spelling variants are one); nil if Solr cannot answer and nothing is kept
  def values
    return BrowseHubs.values(hub, @connection) unless @kind

    Browse::Index.for(@kind, connection: @connection).entries.map { |entry| [ entry.name, entry.count ] }.sort_by { |name, count| [ -count, name ] }
  rescue Browse::Index::Unavailable
    nil
  end
end
