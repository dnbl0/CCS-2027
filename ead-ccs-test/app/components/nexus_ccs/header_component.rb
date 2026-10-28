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

    # [label, href] pairs for the breadcrumb bar; the last item is the current page.
    def breadcrumbs
      case helpers.controller_name
      when "catalog"
        case helpers.action_name
        when "index" then helpers.has_search_parameters? ? [ [ "Search results", nil ] ] : []
        when "show" then [ [ "Search results", results_url ], [ record_title, nil ] ]
        when "advanced_search" then [ [ "Advanced Search", nil ] ]
        else []
        end
      when "bookmarks" then [ [ I18n.t("nexus_ccs.saved.list_title"), nil ] ]
      else []
      end
    end

    # Back to the visitor's last search; with none, the records that have a digital asset as the mosaic (a bare
    # /catalog goes to the home page).
    def results_url
      params = helpers.current_search_session&.query_params.presence
      search_action_url(params || { f: { has_digital_asset: [ "with" ] }, search_field: "all_fields", view: "masonry" })
    end

    # The saved-records bar sits in the breadcrumb strip. A page with no breadcrumb (the home page, the bare search
    # page) keeps it in the header's top strip instead; the content pages draw their own strip (PageBreadcrumbsComponent).
    def saved_in_header? = breadcrumbs.empty? && (helpers.controller_name != "pages" || helpers.action_name == "home")

    # The home page carries the bar over the hero photo (pages/home.html.erb), not in the header's top strip.
    def home_page? = helpers.controller_name == "pages" && helpers.action_name == "home"

    # A record's page has its title band instead of the search banner, and Blacklight's own advanced search page
    # (unmodified) is the search, so the site's search banner does not repeat above it.
    def show_search_banner? = helpers.controller_name == "catalog" && !%w[show advanced_search].include?(helpers.action_name)

    # The advanced search page has the page banner (its h1) under the breadcrumb strip, as the content pages do
    def show_advanced_search_banner? = helpers.controller_name == "catalog" && helpers.action_name == "advanced_search"

    def show_record_banner? = helpers.controller_name == "catalog" && helpers.action_name == "show"

    def record_title
      document = helpers.instance_variable_get(:@document)
      document ? helpers.document_presenter(document).heading : "Record"
    end

    def audience_links = SiteNavigation::AUDIENCE

    # The Browse records menu: its groups of links, then the totals under them (BrowseMenu)
    def browse_counts = @browse_counts ||= BrowseMenu.counts

    def browse_groups = BrowseMenu.groups(browse_counts)

    def browse_path(item) = helpers.search_action_path(BrowseMenu.query(item.field, item.value))

    def all_records_browse_path = helpers.search_action_path(BrowseMenu.all_records_query)

    def with_images_path = helpers.search_action_path(f: { has_digital_asset: [ "with" ] }, search_field: "all_fields")

    def total_count = browse_counts[:total]

    def with_images_count = browse_counts[BrowseMenu::WITH_IMAGES]

    # "13,408" plus "records" for screen readers; nothing when the count is unknown
    def record_count(count)
      return if count.nil?

      tag.span(class: "site-nav__count") { safe_join([ helpers.number_with_delimiter(count), tag.span(" records", class: "visually-hidden") ]) }
    end

    def help_links
      HelpTopic.all.map { |topic| SiteNavigation::Link.new(topic.title, topic.path(helpers)) }
    end

    def help_home = SiteNavigation::Link.new(SiteNavigation::HELP_HOME_LABEL, helpers.help_path)

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
