# frozen_string_literal: true

require "test_helper"

# "Stories from the collection" on the record page (docs/collection-stories.md): drawn from the reviewed data file only, for a record
# whose accession number AND collection match a story's; never a count; never fetched from another site while the page is built.
class RecordCollectionStoriesTest < ActionDispatch::IntegrationTest
  def record_id(accession, collection)
    params = { q: "accession_number_ssim:\"#{accession}\"", fq: "collection_ssim:\"#{collection}\"", fl: "id", rows: 1 }
    Blacklight.default_index.connection.get("select", params: params).dig("response", "docs").first&.fetch("id")
  end

  test "a record with a matched story shows the section: an h2, the story as an h3 card linking to it, and no count" do
    needs_solr
    id = record_id("00.0039", "Grainger Museum Collection") or skip "the Bridgeport baton (00.0039) is not in this index"

    get "/catalog/#{id}"

    assert_response :success
    assert_select "section#collection-stories[aria-labelledby=collection-stories-heading]" do
      assert_select "h2#collection-stories-heading", text: I18n.t("nexus_ccs.collection_stories.heading")
      assert_select "article.collection-story--feature h3.collection-story__title a.collection-story__link[href='/stories/bridgeport-presentation-baton']", text: "Bridgeport Presentation Baton"
      assert_select ".collection-story__source", text: "Grainger Museum"
      assert_select "img.collection-story__image[loading=lazy]"
    end
    section = css_select("#collection-stories").first.text
    assert_no_match(/\d/, section, "no number of stories or records in the section")
  end

  test "a record with no matched story has no section" do
    needs_solr
    id = record_id("00.0001", "Grainger Museum Collection") or skip "00.0001 is not in this index"

    get "/catalog/#{id}"

    assert_response :success
    assert_select "#collection-stories", count: 0
  end

  test "the record page reads only the data file: no other site is fetched while it is built" do
    needs_solr
    id = record_id("00.0039", "Grainger Museum Collection") or skip "the Bridgeport baton (00.0039) is not in this index"
    fetcher = CollectionStories::Fetcher.singleton_class
    fetcher.alias_method :original_call, :call
    fetcher.define_method(:call) { |*| raise "the record page fetched a story site" }

    get "/catalog/#{id}"

    assert_response :success
    assert_select "#collection-stories"
  ensure
    if fetcher&.method_defined?(:original_call)
      fetcher.alias_method :call, :original_call
      fetcher.remove_method :original_call
    end
  end
end
