require "test_helper"
require "view_component/test_helpers"
require "capybara/minitest"
require_relative "../../support/debias_helper"

class DebiasNoticeComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include Capybara::Minitest::Assertions
  include DebiasHelper

  def page = Capybara::Node::Simple.new(rendered_content)

  def render_for(labels: { "title_tsim" => "Title", "description_tsim" => "Description" }, **fields)
    render_inline(NexusCcs::DebiasNoticeComponent.new(matches: DebiasTerms.scan(fields), labels: labels))
  end

  test "no finds, no notice" do
    with_debias_terms("blorp") do
      render_for("title_tsim" => [ "Nothing here" ])
      assert_equal "", rendered_content.strip
    end
    with_debias_terms do
      render_for("title_tsim" => [ "blorp" ])
      assert_equal "", rendered_content.strip
    end
  end

  test "the notice names the term in its context with the explanation, the alternative and the severity in words" do
    with_debias_terms(debias_entry("blorp", severity: "caution", alternative: "zank", explanation: "Made-up reason it may offend.")) do
      render_for("description_tsim" => [ "A long time ago a blorp was catalogued here" ])
    end

    assert_selector "aside[aria-labelledby=record-debias-title] h2#record-debias-title", text: "This record contains language that may be offensive or outdated"
    assert_selector ".record-debias__term", text: "Caution: blorp"
    assert_selector ".record-debias__context", text: "In Description: A long time ago a blorp was catalogued here"
    assert_selector ".record-debias__context mark", text: "blorp"
    assert_text "Made-up reason it may offend."
    assert_text "A more current term: zank"
    assert_selector "aside[data-placeholder-wording]"
  end

  test "it links to the page about the language, the contact card and nothing external" do
    with_debias_terms("blorp") { render_for("title_tsim" => [ "blorp" ]) }

    assert_selector "a[href='/language-in-our-records']", text: "about the language in our records"
    assert_selector "a[href='#contact-collection-heading']", text: "Contact the collection team"
    assert_no_selector "a[href^='http']"
  end

  test "a note and a caution each say which they are, and an entry found twice is listed once with its contexts" do
    with_debias_terms("blorp", debias_entry("zank", severity: "caution")) do
      render_for("title_tsim" => [ "blorp zank" ], "description_tsim" => [ "blorp again", "blorp again" ])
    end

    assert_selector ".record-debias__item", count: 2
    assert_selector ".record-debias__severity", text: "Note:"
    assert_selector ".record-debias__severity", text: "Caution:"
    assert_selector ".record-debias__item--caution", count: 1
    assert_selector ".record-debias__context", count: 3, text: "blorp" # title, description (twice found, once listed)
  end

  test "the explanation and the record's words are escaped" do
    with_debias_terms(debias_entry("blorp", explanation: "<b>bold</b> & <script>x</script>")) do
      render_for("title_tsim" => [ "<i>blorp</i>" ])
    end

    assert_no_selector "b"
    assert_no_selector "script"
    assert_no_selector "i"
    assert_text "<b>bold</b> & <script>x</script>"
  end

  test "a long list is cut with a count of the rest" do
    terms = (1..12).map { |i| "blorp#{('a'.ord + i).chr}" }
    with_debias_terms(*terms) { render_for("title_tsim" => [ terms.join(" ") ]) }

    assert_selector ".record-debias__item", count: NexusCcs::DebiasNoticeComponent::MAX_ENTRIES
    assert_text "4 more flagged terms"
  end
end

class RecordDebiasTest < ActiveSupport::TestCase
  include DebiasHelper

  # The part of RecordDocumentComponent the notice uses, without Solr or a presenter
  Row = Struct.new(:label, :values, :field, :copy, keyword_init: true)
  class Host
    include NexusCcs::RecordDebias
    Row = RecordDebiasTest::Row
    attr_reader :rows

    def heading = "blorp" # the title, shown in the header and scanned with the details

    def initialize(rows) = @rows = rows
    def link_to_value?(row) = row.field == "collection_ssim"
    def t(key) = I18n.t(key)
  end

  test "only the displayed rows are scanned, the copy and link rows are not, and flagged marks one value of one field" do
    host = Host.new([ Row.new(label: "UoM ID", values: [ "blorp" ], field: "id", copy: true),
                      Row.new(label: "Collection", values: [ "blorp" ], field: "collection_ssim"),
                      Row.new(label: "Subject", values: [ "plain", "a blorp" ], field: "subject_ssim") ])

    with_debias_terms("blorp") do
      assert_equal %w[title_tsim subject_ssim], host.debias_matches.map(&:field)
      assert_equal({ "title_tsim" => "Title", "id" => "UoM ID", "collection_ssim" => "Collection", "subject_ssim" => "Subject" }, host.debias_labels)
      assert_equal "plain", host.flagged(host.rows.last, "plain", 0)
      assert_includes host.flagged(host.rows.last, "a blorp", 1), %(<span class="visually-hidden">flagged term: </span>blorp)
    end
  end

  test "with no terms flagged returns the very same value" do
    host = Host.new([ Row.new(label: "Subject", values: [ "blorp" ], field: "subject_ssim") ])
    with_debias_terms do
      value = "blorp"
      assert_same value, host.flagged(host.rows.first, value, 0)
      assert_equal "blorp", host.title_markup
    end
  end
end
