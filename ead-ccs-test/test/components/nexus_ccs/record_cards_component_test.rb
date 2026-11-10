# frozen_string_literal: true

require "test_helper"

class RecordCardsComponentTest < ViewComponent::TestCase
  def docs(count) = Array.new(count) { |n| SolrDocument.new({ "id" => "emu-#{n}", "title_tsim" => [ "Record #{n}" ] }) }

  def render_cards(documents, **options)
    render_inline NexusCcs::RecordCardsComponent.new(id: "related", heading: "Related objects", documents: documents, **options)
  end

  test "a section is named by its h2, with one card per record" do
    render_cards(docs(2), description: "Records like this one.")

    assert_selector "section#related[aria-labelledby=related-heading] h2#related-heading", text: "Related objects"
    assert_selector ".object-cards__description", text: "Records like this one."
    assert_selector "ul.object-cards__list > li article.object-card", count: 2
  end

  test "at most four cards" do
    render_cards(docs(7))

    assert_selector "article.object-card", count: 4
  end

  test "no records, no section" do
    render_cards([])

    assert_no_selector "section"
  end

  test "the compact variant for Recently viewed" do
    render_cards(docs(1), compact: true)

    assert_selector "section.object-cards--compact article.object-card--compact"
  end
end
