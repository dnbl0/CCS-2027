# frozen_string_literal: true

# Themed collections (Themes, config/themes.yml): /themes lists them, /themes/:slug shows one theme's introduction, highlights and
# commonest object types and eras, and opens its records in the search page.
class ThemesController < ApplicationController
  include DiscoveryPage

  def index
    @themes = Themes.all
    use_meta t("nexus_ccs.themes.title"), t("nexus_ccs.themes.description"), [ [ t("nexus_ccs.themes.title"), nil ] ]
  end

  def show
    @theme = Themes.find(params[:slug]) || not_found!
    @showcase = Showcase.call(fq: @theme.fq, first: @theme.hero) || (return unavailable!)
    use_meta @theme.title, @theme.intro, [ [ t("nexus_ccs.themes.title"), themes_path ], [ @theme.title, nil ] ]
  end
end
