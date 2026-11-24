# frozen_string_literal: true

require "application_system_test_case"

# The category, collection, theme and story pages, the home page's new sections and the lists explainer in a real browser
# (docs/categories-themes-stories.md): axe (WCAG 2.2 AA) and no sideways scroll on a desktop and at 390px wide. The category lists are given
# to the pages through the cache; the theme and story pages read the test index (they say so plainly when it is down).
class DiscoveryPagesSystemTest < ApplicationSystemTestCase
  PAGES = %w[/browse/categories /browse/categories/regions /themes /themes/twentieth-century-prints /stories /stories/example-story /lists /].freeze

  setup do
    page.driver.set_cookie("country_acknowledged", "1")
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    picture = { "id" => "r1", "title" => "A print", "path" => "/digital-assets/thumbs/0000_013_1_pf.jpg", "width" => 400, "height" => 300 }
    Categories.all.each do |dimension|
      rows = (1..12).map { |n| { "value" => "#{dimension.title} example with a long name #{n}", "count" => 1000 - n, "image" => (picture if n.odd?) } }
      Rails.cache.write(SuppressedRecord.cache_key("categories/v1/#{dimension.slug}"), rows, expires_in: 1.day)
    end
  end

  teardown { Rails.cache = @cache }

  [ [ "a desktop", 1440, 900 ], [ "a phone", 390, 844 ] ].each do |name, width, height|
    test "on #{name}: no axe violations and no sideways scroll" do
      page.current_window.resize_to(width, height)
      PAGES.each do |path|
        visit path
        assert_selector "h1"
        assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)
        assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth"), "#{path} scrolls sideways at #{width}px"
      end
    end
  end

  test "a category card's count stays visible on a phone" do
    page.current_window.resize_to(320, 700)
    visit "/browse/categories/regions"

    # the count, its own line under the name (the mosaic's cards) or on the picture (the four that lead, as a cluster)
    assert_selector "article.explore-card .explore-card__intro, .cluster__card .cluster__text", text: /\A\d{3} records\z/, count: 12
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
  end
end
