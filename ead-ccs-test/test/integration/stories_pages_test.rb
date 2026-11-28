# frozen_string_literal: true

require "test_helper"
require_relative "../support/outages"

# /stories after the British Museum's blog (its newest story large, then a grid of cards), and the stories about collection objects
# read on this site rather than on the website that first published them. Solr is not needed: the cards and pages keep their own
# text and pictures when the index cannot answer.
class StoriesPagesTest < ActionDispatch::IntegrationTest
  include Outages

  setup { Outages::SolrDown.active = true }
  teardown { Outages::SolrDown.active = false }

  test "the stories page: one large story first, then cards with a category, the headline linking to the story here, and Read more" do
    get "/stories"

    assert_response :success
    assert_select ".stories-index__item--lead .story-card--lead", count: 1
    assert_select ".stories-index__item--lead:first-child"
    assert_select ".story-card h2.story-card__title a.story-card__link", minimum: 20
    assert_select ".story-card__kicker", text: %r{\AMuseums Victoria\z}
    assert_select ".story-card__kicker", text: %r{\AGrainger Museum / [A-Z][a-z]+ \d{4}\z}
    assert_select ".story-card__more[aria-hidden=true]", text: "Read more"
    assert_select ".story-card__link[href^='http']", count: 0, message: "every story opens on this site"
    assert_select ".story-card__image[alt='']"
  end

  test "a Museums Victoria story is read here in full, credited, with its licence" do
    get "/stories/csirac-collection"

    assert_response :success
    assert_select "h1", "CSIRAC Collection"
    assert_select ".story-page__meta", text: /Museums Victoria · By Mr David Demant/
    assert_select ".story-page__text", text: /first stored memory digital electronic computer in Australia/
    assert_select ".story-page__figure img.story-page__image[src^='https://collections.museumsvictoria.com.au/']"
    assert_select ".story-page__source a[href='https://collections.museumsvictoria.com.au/articles/3145']", text: "Museums Victoria"
    assert_select ".story-page__source a[href='https://creativecommons.org/licenses/by/4.0']", text: "CC BY"
    assert_select ".story-page__text script", count: 0
  end

  test "a Grainger Museum story is here as its summary, dated by its month, with a link to the full text on the museum's site" do
    get "/stories/bridgeport-presentation-baton"

    assert_response :success
    assert_select "h1", "Bridgeport Presentation Baton"
    assert_select ".story-page__meta", text: /Grainger Museum · Published [A-Z][a-z]+ \d{4}/
    assert_select ".story-page__more a[href^='https://grainger.unimelb.edu.au/']", text: "Read the full story on the Grainger Museum website"
    assert_select ".story-page__source", text: /first published by Grainger Museum/
  end
end
