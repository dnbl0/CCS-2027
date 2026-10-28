# frozen_string_literal: true

# The parts of the site header that depend on which page is showing (see CONTEXT.md, "Page chrome"):
#
#   breadcrumbs  [label, href] pairs for the breadcrumb strip; the last item is the current page
#   banner       what sits under the strip: :search (the search banner), :record (the record's title band),
#                :advanced_search (the page banner), or nil
#   saved_bar    where the saved-records bar goes: :breadcrumb (in the breadcrumb strip), :header (the header's top strip,
#                for a page with no trail), :hero (over the home page's photo, pages/home.html.erb), or :page (a content
#                page draws its own strip, PageBreadcrumbsComponent)
#
# HeaderComponent renders it; a header for a page the rules do not know (StockHeaderComponent) builds its own.
PageChrome = Data.define(:breadcrumbs, :banner, :saved_bar) do
  # The chrome of a page of the site, from its controller and action. `searching` is whether the catalog has a search
  # to show; `page` answers record_title and results_url, and is asked only on a record page.
  def self.for(controller:, action:, searching: false, page: nil)
    case [ controller, action ]
    in [ "pages", "home" ] then new(breadcrumbs: [], banner: nil, saved_bar: :hero)
    in [ "pages", _ ] then new(breadcrumbs: [], banner: nil, saved_bar: :page)
    in [ "catalog", "index" ]
      searching ? with_trail([ [ "Search results", nil ] ], banner: :search) : new(breadcrumbs: [], banner: :search, saved_bar: :header)
    in [ "catalog", "show" ] then with_trail(record_trail(page.record_title, page.results_url), banner: :record)
    in [ "catalog", "advanced_search" ] then with_trail([ [ "Advanced Search", nil ] ], banner: :advanced_search)
    in [ "catalog", _ ] then new(breadcrumbs: [], banner: :search, saved_bar: :header)
    in [ "bookmarks", _ ] then with_trail([ [ I18n.t("nexus_ccs.saved.list_title"), nil ] ], banner: nil)
    else new(breadcrumbs: [], banner: nil, saved_bar: :header)
    end
  end

  # Blacklight's own record page inside the site header (/branded-stock/:id): a record's trail, and no banner, as the
  # page under it brings its own title.
  def self.stock_record(record_title:, results_url:) = with_trail(record_trail(record_title, results_url), banner: nil)

  def self.record_trail(title, results_url) = [ [ "Search results", results_url ], [ title, nil ] ]

  def self.with_trail(breadcrumbs, banner:) = new(breadcrumbs: breadcrumbs, banner: banner, saved_bar: :breadcrumb)

  private_class_method :record_trail, :with_trail

  # Phones hide the header's top strip, and the home page has no breadcrumb strip, so the phone menu carries the
  # saved-records link on those pages.
  def saved_link_in_phone_menu? = saved_bar.in?(%i[header hero])
end
