# frozen_string_literal: true

require "test_helper"

class LookCloserComponentTest < ViewComponent::TestCase
  def pick(crops: 20, tint: "#e0d6c5")
    HomeLookCloser::Pick.new(id: "emu-1", title: "A fern gully", maker: nil, image: "https://unimelbourne.widen.net/content/a/jpeg/x.jpg?w=1600", tint: tint,
                             crops: Array.new(crops) { |index| HomeLookCloser::Crop.new(x: 0.01 * index, y: 0.02 * index, size: 0.1 + (0.01 * index), aspect: 1.5) })
  end

  test "the band: its squares are one picture, decoration out of the tab order; the panel asks for a guess and links to the record" do
    render_inline NexusCcs::LookCloserComponent.new(pick: pick)

    assert_selector "section.look-closer[aria-labelledby=look-closer-heading][style*='--band: #e0d6c5']"
    assert_selector ".look-closer__column", count: NexusCcs::LookCloserComponent::COLUMNS.size
    assert_selector "a.look-closer__piece[tabindex='-1'][aria-hidden=true][href='/catalog/emu-1'] img[alt=''][loading=lazy]", count: 20
    assert_equal 1, page.all(".look-closer__piece img").map { |img| img[:src] }.uniq.size, "one picture, downloaded once"
    assert_selector ".look-closer__panel h2#look-closer-heading", text: "Guess the work from the pieces"
    assert_selector ".look-closer__panel a.look-closer__answer[href='/catalog/emu-1']", text: "Find out what it is"
    # the largest close-up in the largest square (the wide column's first)
    assert_selector ".look-closer__column--wide .look-closer__piece:first-child[style*='--s: 0.29']"
  end

  test "nothing without a record, or with too few close-ups to fill the band" do
    render_inline NexusCcs::LookCloserComponent.new(pick: nil)
    assert_no_selector "section"
    render_inline NexusCcs::LookCloserComponent.new(pick: pick(crops: 5))
    assert_no_selector "section"
  end
end
