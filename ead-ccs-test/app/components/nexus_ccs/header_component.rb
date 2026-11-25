# frozen_string_literal: true

module NexusCcs
  # University of Melbourne Gen 3 header. Replaces Blacklight's top navbar
  # (config.header_component) and keeps Blacklight's search bar in the band beneath it.
  class HeaderComponent < Blacklight::HeaderComponent
    delegate :search_action_url, to: :helpers

    # The gem's top navbar is replaced by the site header (so it is never rendered),
    # and its light search band by the dark search banner.
    def before_render
      with_search_bar(component: NexusCcs::SearchBannerComponent) unless search_bar
    end

    # Which trail, banner and saved-bar place this page has (PageChrome)
    def chrome
      @chrome ||= PageChrome.for(controller: helpers.controller_name, action: helpers.action_name,
                                 searching: helpers.controller_name == "catalog" && helpers.has_search_parameters?, page: self)
    end

    def breadcrumbs = chrome.breadcrumbs

    # Back to the visitor's last search; with none, the records that have a digital asset as the mosaic (a bare
    # /catalog goes to the home page).
    def results_url
      params = helpers.current_search_session&.query_params.presence
      search_action_url(params || { f: { has_digital_asset: [ "with" ] }, search_field: "all_fields", view: "masonry" })
    end

    # A record page's parent in the trail (docs/ia-audit-handover.md): Browse when the visitor came to it from a Browse page, a collection,
    # a theme or a story on this site (the referrer), else their search results
    BROWSE_REFERRER = %r{\A/(browse|themes|stories)(/|\z)}

    def record_parent
      referrer = URI.parse(helpers.request.referer.to_s) rescue nil
      from_browse = referrer && referrer.host == helpers.request.host && referrer.path.to_s.match?(BROWSE_REFERRER)
      from_browse ? [ I18n.t("browse.title"), helpers.browse_path ] : [ "Search results", results_url ]
    end

    # The trail of a browse page, set by BrowseController as [label, href] pairs
    def browse_trail = helpers.instance_variable_get(:@browse_trail) || []

    def record_title
      document = helpers.instance_variable_get(:@document)
      document ? helpers.document_presenter(document).heading : "Record"
    end

    def audience_links = SiteNavigation::AUDIENCE

    # The Search collections menu: the collections, then the records with images under them (BrowseMenu)
    def browse_counts = @browse_counts ||= BrowseMenu.counts

    def browse_groups = BrowseMenu.groups(browse_counts)

    # a collection opens its own page (as everywhere else on the site: the menu lists only collections with records, so each has one; the
    # address is built, never looked up, so the header asks Solr nothing); any other value, its records in the search
    def browse_path(item)
      return helpers.collection_landing_path(kind: "collections", slug: Browse::Slug.build("collections", item.value)) if item.field == BrowseMenu::COLLECTION_FIELD

      helpers.search_action_path(BrowseMenu.query(item.field, item.value))
    end

    def with_images_path = helpers.search_action_path(f: { has_digital_asset: [ "with" ] }, search_field: "all_fields")

    def help_links
      HelpTopic.all.map { |topic| SiteNavigation::Link.new(topic.title, topic.path(helpers)) }
    end

    def help_home = SiteNavigation::Link.new(SiteNavigation::HELP_HOME_LABEL, helpers.help_path)

    # The visitor's own pages, Blacklight's: saved records, lists, saved searches and the search history. The first three
    # are hidden while config.x.saved_records is off (config/application.rb).
    def saved_links
      links = []
      if Rails.configuration.x.saved_records
        links << SiteNavigation::Link.new(I18n.t("nexus_ccs.saved.list_title"), helpers.bookmarks_path)
        links << SiteNavigation::Link.new(I18n.t("nexus_ccs.lists.title"), helpers.lists_path)
        links << SiteNavigation::Link.new(I18n.t("nexus_ccs.saved_searches.title"), helpers.saved_searches_path)
      end
      links << SiteNavigation::Link.new(I18n.t("nexus_ccs.search_history.title"), helpers.search_history_page_path)
      links << SiteNavigation::Link.new(I18n.t("nexus_ccs.compare.menu"), helpers.compare_path) # reachable again once items are added
      # How Save, lists and shared galleries work: a short explainer on the lists page
      links << SiteNavigation::Link.new(I18n.t("nexus_ccs.lists_help.link"), helpers.lists_path(anchor: "how-saving-works")) if Rails.configuration.x.saved_records
      links
    end

    # The Browse menu: every way in, in the order of the Browse page's sections (docs/ia-audit-handover.md), then themes and stories
    def browse_more_links
      [ [ I18n.t("nexus_ccs.categories.dimensions.collections.title"), helpers.category_path("collections") ],
        [ "Object types", helpers.browse_hub_path("object-types") ],
        [ I18n.t("nexus_ccs.categories.dimensions.classifications.title"), helpers.category_path("classifications") ],
        [ I18n.t("explore_pages.places.title"), helpers.explore_places_path ],
        [ I18n.t("explore_pages.time.title"), helpers.explore_time_path ],
        [ I18n.t("colours.title"), helpers.explore_colours_path ],
        [ "Makers", helpers.browse_hub_path("makers") ],
        [ "Subjects", helpers.browse_hub_path("subjects") ],
        [ I18n.t("nexus_ccs.themes.title"), helpers.themes_path ],
        [ I18n.t("nexus_ccs.stories.title"), helpers.stories_path ] ].map { |label, href| SiteNavigation::Link.new(label, href) }
    end

    def about = SiteNavigation::Link.new(SiteNavigation::ABOUT_LABEL, helpers.about_path)

    def all_records_path = helpers.search_catalog_path

    # The nav link opens the catalog on the All Fields search; the search form needs the bare path as its action.
    def all_records_link_path = helpers.search_catalog_path(search_field: "all_fields")

    # "<" icon and label of the row that leaves a drilled-in menu section on mobile.
    def back_label
      safe_join([ tag.svg(tag.polyline(points: "15 5 8 12 15 19"), viewBox: "0 0 24 24", aria: { hidden: true }), "Back" ])
    end
  end
end
