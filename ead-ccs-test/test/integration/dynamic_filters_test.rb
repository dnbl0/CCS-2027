require "test_helper"

# CCS-212 (BR-05.06): the filters narrow as the search does. Solr counts every filter value against the current results
# (Blacklight asks for values with at least one record), so choosing a value drops the filters and values that no longer
# apply and re-counts the rest. These read the sidebar HTML of real searches.
class DynamicFiltersTest < ActionDispatch::IntegrationTest
  BASE = { q: "", any_assets: "1" }.freeze
  MUSEUM = { f: { collection_ssim: [ "Medical History Museum" ] } }.freeze

  def sidebar(params)
    get "/catalog", params: params
    assert_response :success
    Nokogiri::HTML5(response.body).at_css(".filter-sidebar")
  end

  # { "Object Type" => { "photograph" => 993, ... } } for the filters that have values
  def facet_counts(sidebar)
    sidebar.css(".accordion-item.facet-limit").to_h do |item|
      values = item.css("ul.facet-values li").filter_map do |li|
        label = li.at_css(".facet-label")&.text&.strip
        count = li.at_css(".facet-count")&.text&.delete(",")
        [ label, count.to_i ] if label && count
      end
      [ item.at_css(".accordion-button").text.squish, values.to_h ]
    end
  end

  test "choosing a value re-counts the other filters for the narrowed results and drops the values that no longer apply" do
    needs_solr
    before = facet_counts(sidebar(BASE))
    after = facet_counts(sidebar(BASE.merge(MUSEUM)))

    assert_operator after["Object Type"].values.sum, :<, before["Object Type"].values.sum
    # (each list shows only its top 20, so a value that was below the line before can appear after)
    assert after["Object Type"].all? { |value, count| count <= before["Object Type"].fetch(value, count) }, "a count grew after narrowing"
    assert_equal 1, after["Collection Title"].size, "other collections have no records in this one"
    assert after["Collection Title"].keys.first.start_with?("Medical History Museum")
  end

  test "a filter left with no values is not offered" do
    needs_solr
    before = facet_counts(sidebar(BASE))
    after = facet_counts(sidebar(BASE.merge(MUSEUM)))

    gone = before.select { |_, values| values.any? }.keys - after.select { |_, values| values.any? }.keys
    assert_includes gone, "Materials / Medium"
    assert_not_includes after.select { |_, values| values.any? }.keys, "Materials / Medium"
  end

  test "no filter value is offered with a count of 0" do
    needs_solr
    [ BASE, BASE.merge(MUSEUM), { q: "skull", any_assets: "1" } ].each do |params|
      counts = facet_counts(sidebar(params))
      counts.each { |name, values| assert values.values.all?(&:positive?), "#{name} offers a value with no records" }
    end
  end

  test "the sidebar has a polite status that says how many results and filters apply" do
    needs_solr
    sidebar = sidebar(BASE.merge(MUSEUM))
    status = sidebar.at_css("[data-filter-state-target=status]")

    assert_equal "status", status["role"]
    assert_equal "polite", status["aria-live"]
    assert_equal "true", status["aria-atomic"]
    assert_match(/\A[\d,]+ results, 1 filter applied\z/, sidebar["data-filter-state-message-value"])
    assert_empty status.text.strip, "the message is put in the status after the page shows, so it is announced"
  end

  test "the status counts several filters and a single result" do
    needs_solr
    two = sidebar(BASE.merge(f: { collection_ssim: [ "Medical History Museum" ], object_type_ssim: [ "photograph" ] }))
    assert_match(/results, 2 filters applied\z/, two["data-filter-state-message-value"])

    none = sidebar(q: "zzzzqqqq", any_assets: "1")
    assert_equal "0 results, no filters applied", none["data-filter-state-message-value"]
  end
end
