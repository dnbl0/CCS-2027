require "test_helper"

# You may be interested in shows the search results' cards (ResultCardComponent through discover/_cards), so the record page's own
# stylesheets must not restyle the card: its border, background, picture, title and lines come from result_card.css alone. Laying the
# cards out (their grid, a card's flex) is the only thing the record page may set.
class RecordCardsNoDriftTest < ActiveSupport::TestCase
  STYLESHEETS = %w[record.css record_split.css record_page.css].freeze
  LAYOUT_ONLY = /\A\s*flex:\s*0 0 auto;\s*\z/

  test "the record page's stylesheets restyle no part of the result card" do
    STYLESHEETS.each do |name|
      css = Rails.root.join("app/assets/stylesheets/components", name).read.gsub(%r{/\*.*?\*/}m, "")
      css.scan(/([^{}]*\.result-card[^{}]*)\{([^{}]*)\}/).each do |selector, body|
        assert_match LAYOUT_ONLY, body, "#{name} restyles the result card: #{selector.strip} { #{body.strip} }"
      end
    end
  end
end
