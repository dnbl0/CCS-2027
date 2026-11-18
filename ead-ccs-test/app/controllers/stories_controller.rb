# frozen_string_literal: true

# Stories (Stories, content/stories/*.md): /stories lists them, newest first; /stories/:slug draws one, with its record and search embeds.
# The embeds' records come from one request for every embedded record and one search per search embed, kept for an hour.
class StoriesController < ApplicationController
  include DiscoveryPage

  SEARCH_ROWS = NexusCcs::RecordCardsComponent::MAX
  TTL = 1.hour

  def index
    @stories = Stories.all
    use_meta t("nexus_ccs.stories.title"), t("nexus_ccs.stories.description"), [ [ t("nexus_ccs.stories.title"), nil ] ]
  end

  def show
    @story = Stories.find(params[:slug]) || not_found!
    @parts = @story.parts
    @embedded = embedded(@parts.grep(Stories::Embed), @story.hero)
    use_meta @story.title, @story.summary, [ [ t("nexus_ccs.stories.title"), stories_path ], [ @story.title, nil ] ]
  end

  private

  # { "records" => { id => SolrDocument }, "searches" => { index => { "total", "docs" } } }; empty when Solr cannot answer (the story's
  # text is still shown)
  def embedded(embeds, hero)
    ids = ([ hero ] + embeds.select { |embed| embed.kind == :record }.map(&:value)).compact.uniq
    key = SuppressedRecord.cache_key("stories/v1/#{@story.slug}/#{Digest::SHA256.hexdigest(@story.body + hero.to_s)}")
    kept = Rails.cache.fetch(key, expires_in: TTL, skip_nil: true) do
      { "records" => Discovery.fetch(ids).to_h { |document| [ document.id.to_s, document._source ] },
        "searches" => embeds.each_with_index.select { |embed, _| embed.kind == :search }.to_h { |embed, index| [ index, search(embed.value) ] } }
    rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable, Blacklight::Exceptions::InvalidRequest => e
      Rails.logger.warn("Story embeds unavailable: #{e.class}")
      nil
    end || { "records" => {}, "searches" => {} }
    { records: kept["records"].transform_values { |source| SolrDocument.new(source) },
      searches: kept["searches"].transform_values { |found| { total: found["total"], documents: found["docs"].map { |doc| SolrDocument.new(doc) } } } }
  end

  # The first results of the embed's search, as the search page finds them (the catalog's own search builder), withheld ones left out
  def search(params)
    state = Blacklight::SearchState.new(ActionController::Parameters.new(params.merge("rows" => SEARCH_ROWS.to_s)), CatalogController.blacklight_config, self)
    found = Blacklight::SearchService.new(config: CatalogController.blacklight_config, search_state: state).search_results
    { "total" => found.total, "docs" => found.documents.select { |document| Discovery.listable?(document) }.map(&:_source) }
  end
end
