# frozen_string_literal: true

# Themed collections (Themes, config/themes.yml): the Stories page lists them (its Themes section); /browse/themes/:slug shows one theme's introduction, highlights and
# commonest object types and eras, and opens its records in the search page.
class ThemesController < ApplicationController
  include DiscoveryPage

  def show
    @theme = Themes.find(params[:slug]) || not_found!
    @showcase = Showcase.call(fq: @theme.fq, first: @theme.hero, highlights: Showcase::PAGE_HIGHLIGHTS) || (return unavailable!)
    @pictures = Browse::FacetPictures.for(@theme.fq, avoid: @showcase.documents.map(&:id))
    use_meta @theme.title, @theme.intro, [ [ t("browse.title"), browse_path ], [ t("nexus_ccs.stories.title"), stories_path ], [ @theme.title, nil ] ]
  end
end
