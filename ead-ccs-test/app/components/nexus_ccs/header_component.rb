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
