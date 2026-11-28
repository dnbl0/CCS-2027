# frozen_string_literal: true

require "test_helper"

# The site owner's standing rule (docs/decisions-2027.md): no counts of records anywhere on the site, only names and pictures.
# Allowed: the search results page's total and its filter counts, and the visitor's own counts (saved records, lists, selections).
# Each page below is a browse or explore page, so none may show a number of records, results, categories or places.
class NoCountsTest < ActionDispatch::IntegrationTest
  COUNT = /\b\d[\d,]*\s+(?:records?|results?|categories|places|objects?)\b|\(\d[\d,]*\)/

  PAGES = %w[/ /browse /browse/categories /browse/collections /browse/creators /browse/places /browse/periods /explore/time
             /explore/places /explore/colours /stories /discover].freeze

  # The visible text of the page, without the parts that may count (the visitor's own saved bar and selections) and without
  # record cards, whose titles are the records' own ("Unused certificates (3)"), and story summaries, which are the publisher's
  # own words ("The CSIRAC Computer collection consists of over 300 objects", Museums Victoria): the site counts nothing there
  def visible_text
    page = Nokogiri::HTML(response.body)
    page.css("script, style, template, .saved-bar, .selection-stepper, [hidden], [data-document-id], .object-card, .story-card__summary")
        .each(&:remove)
    page.at("body")&.text.to_s.squish
  end

  test "the header's Search collections menu shows no counts, on every page" do
    get "/"
    menu = css_select(".site-nav__panel, .site-nav").map(&:text).join(" ").squish
    assert_no_match(/\d[\d,]{2,}/, menu, "the header menu shows a number of records")
  end

  test "browse and explore pages show names and pictures, never a number of records" do
    needs_solr
    PAGES.each do |path|
      get path
      next unless response.successful?

      found = visible_text.scan(COUNT).first
      assert_nil found, "#{path} shows a count: #{found.inspect}"
    end
  end

  # Entity, collection, category, period and story pages, reached from the hubs as a visitor would
  test "the pages the hubs lead to show no counts either" do
    needs_solr
    details = %w[/browse /browse/categories /browse/creators /browse/periods /stories].flat_map do |hub|
      get hub
      next [] unless response.successful?

      css_select("main a[href]").map { |link| link["href"] }.grep(%r{\A/(?:browse/[a-z-]+/[^/?#]+|stories/[a-z0-9-]+)\z}).first(3)
    end
    skip "no detail pages in this index" if details.empty?

    details.uniq.each do |path|
      get path
      next unless response.successful?

      found = visible_text.scan(COUNT).first
      assert_nil found, "#{path} shows a count: #{found.inspect}"
    end
  end
end
