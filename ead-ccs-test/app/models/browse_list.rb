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

  # region: the Places page's region (PlaceRegions), for places only
  def initialize(hub, letter: nil, filter: nil, page: nil, connection: nil, region: nil)
    @hub = hub
    @connection = connection
    @kind = Browse::Kind.find(hub.slug)
    @all = periods? ? BrowseHubs.period_entries(connection) : values
    @letter = letter.to_s.upcase if !periods? && letters.include?(letter.to_s.upcase)
    @filter = filter.to_s.squish.first(80).presence unless periods?
    @page = page.to_i
    @region = region.to_s if hub.slug == "places" && regions.any? { |name, _count| name == region.to_s }
  end

  attr_reader :hub, :letter, :filter, :region

  # The Places page's regions, with how many places each (none for any other list)
  def regions = @regions ||= hub.slug == "places" && available? ? PlaceRegions.counts(@all) : []

  def available? = !@all.nil?

  def periods? = hub.slug == "periods"

  def letters = @letters ||= available? && !periods? ? BrowseHubs.letters(@all) : []

  # Everything the page lists, before paging: [[value, count], ...] or the periods
  def chosen
    return @all.to_a if periods?

    list = @all
    list = list.select { |value, _count| PlaceRegions.region_of(value) == region } if region
    list = list.select { |value, _count| Browse::Slug.fold(value).include?(Browse::Slug.fold(filter)) } if filter
    return BrowseHubs.for_letter(list, letter) if letter

    filter || region ? list : list.first(BrowseHubs::MOST_RECORDS)
  end

  def paged? = (letter || filter || region) && chosen.size > PAGE_SIZE

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
    return [ "Matching “#{filter}”", (" in #{region}" if region) ].join if filter && !letter
    return "Places in #{region}, starting with #{letter == BrowseHubs::OTHER_LETTER ? 'a number or sign' : letter}" if region && letter
    return "Places in #{region}" if region && !letter
    return "Starting with #{letter == BrowseHubs::OTHER_LETTER ? 'a number or sign' : letter}" if letter

    periods? ? "All periods" : "Most records"
  end

  def total = available? ? @all.size : 0

  # "Showing 1–120 of 312": the first and last shown, and how many are chosen
  def range
    size = chosen.size
    first = size.zero? ? 0 : (page - 1) * PAGE_SIZE + 1
    [ first, [ page * PAGE_SIZE, size ].min, size ]
  end

  # A value's number of records (every record, as the list counts them), nil when the list does not have it: the Places wall's cards
  # are found among the pictured records, so their own counts are smaller
  def count_of(label)
    @counts ||= Array(@all).to_h { |value, count| [ value.to_s.downcase, count ] }
    @counts[label.to_s.downcase]
  end

  private

  # Makers, places and subjects are grouped (spelling variants are one); nil if Solr cannot answer and nothing is kept
  def values
    return BrowseHubs.values(hub, @connection) unless @kind

    Browse::Index.for(@kind, connection: @connection).entries.map { |entry| [ entry.name, entry.count ] }.sort_by { |name, count| [ -count, name ] }
  rescue Browse::Index::Unavailable
    nil
  end
end
