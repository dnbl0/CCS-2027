# Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
Rails.application.routes.draw do
  # Hyphenated addresses (docs/ia-audit-handover.md): the visitor's own pages answer at /saved-searches, /search-history, /my-data and
  # /access-requests; the old underscored ones answer 301 with the query kept. Before Blacklight's engine, so its /search_history redirects.
  %w[saved_searches search_history my_data].each do |old|
    get old, as: "legacy_#{old}", to: redirect(status: 301) { |_params, request| [ "/#{old.tr('_', '-')}", request.query_string.presence ].compact.join("?") }
  end
  get "access_requests/new", as: :legacy_access_request, to: redirect(status: 301) { |_params, request| [ "/access-requests/new", request.query_string.presence ].compact.join("?") }
  get "search-history", to: "search_history#index", as: :search_history_page
  concern :range_searchable, BlacklightRangeLimit::Routes::RangeSearchable.new
  mount Blacklight::Engine => "/"
  root to: "pages#home"
  concern :searchable, Blacklight::Routes::Searchable.new
  concern :exportable, Blacklight::Routes::Exportable.new

  # The records ticked on the results pages (CCS-40): kept in the session cookie, so not behind the saved records setting below
  resource :selection, only: [ :show, :create ] do
    get "citations"
  end

  # scope constraint to address Rails default :id segment stopping at dots in ids
  scope constraints: { id: %r{[^/]+} } do
    resource :catalog, only: [], as: "catalog", path: "/catalog", controller: "catalog" do
      concerns :searchable
      concerns :range_searchable
    end
    # Blacklight's default record routes, without its Email and SMS pages: the site offers neither (only Cite)
    resources :solr_documents, only: [ :show ], path: "/catalog", controller: "catalog" do
      member { get "citation" }
    end
    # Sensitive records (CCS-227): the visitor's choice to view the assets or not. Export of a record's metadata (CCS-163).
    post "catalog/:id/sensitivity", to: "sensitivity_choices#create", as: :sensitivity_choice
    # The record's images as an IIIF Presentation manifest (CCS-57), and the comparison of records or images side by side (CCS-58)
    get "catalog/:id/manifest.json", to: "manifests#show", as: :manifest, format: false
    get "compare", to: "compare#show", as: :compare
    post "compare/items", to: "compare#create", as: :compare_items
    delete "compare/items/:id", to: "compare#destroy", as: :compare_item
    delete "compare", to: "compare#clear", as: :clear_compare
    get "catalog/:id/metadata", to: "metadata_exports#show", as: :metadata_export
    # The saved list and its Save / Remove requests are a 404 while config.x.saved_records is off (config/application.rb)
    constraints(->(_request) { Rails.configuration.x.saved_records }) do
      resources :bookmarks, only: [ :index, :update, :create, :destroy ] do
        concerns :exportable
        collection do
          delete "clear"
          get "citations"
        end
      end
      resources :saved_searches, only: [ :index, :create, :destroy ], path: "saved-searches"
      # Delete my data (CCS-148): what the site holds against the visitor's cookie, shown, then removed
      resource :my_data, only: [ :show, :destroy ], controller: "my_data", path: "my-data"
      # Bulk download of the selected records' digital assets (CCS-167): review what will be sent, then the zip
      post "downloads/review", to: "bulk_downloads#review", as: :review_bulk_download
      post "downloads", to: "bulk_downloads#create", as: :bulk_download
      # Named lists (CCS-389); a list's records are added and removed at /lists/:list_id/items
      resources :lists do
        member { get "citations" }
        resources :items, controller: "list_items", only: [ :create, :destroy ]
      end
    end
  end

  # Asking for access to a record (CCS-69): the form, and the confirmation only the requester's own session can open
  resources :access_requests, only: [ :new, :create, :show ], path: "access-requests"

  # The new record page, for the records in StockRecords only (any other id is a 404): Blacklight out of the box (StockCatalogController),
  # and the same page in the UoM header, breadcrumb and footer (BrandedStockCatalogController). The site's own record page, /catalog/:id,
  # is unchanged.
  constraints(->(request) { StockRecords.include?(request.path_parameters[:id]) }) do
    scope constraints: { id: %r{[^/]+} } do
      resources :stock_documents, only: [ :show ], path: "/stock", controller: "stock_catalog" do
        member { get "citation" }
      end

      resources :branded_stock_documents, only: [ :show ], path: "/branded-stock", controller: "branded_stock_catalog" do
        member { get "citation" }
      end
    end
  end

  # Browse collections is gone (the sitemap keeps Blacklight's own pages): its address goes to the collection cards on the home
  # page, and each old collection landing page goes to the results filtered to that collection.
  # Take one search out of the history (Blacklight draws /search_history and /search_history/clear)
  delete "search-history/:id", to: "search_history#destroy", as: :search_history_entry, constraints: { id: /\d+/ }

  get "collections", to: redirect("/browse/collections", status: 301)
  get "collections/:slug", to: redirect(status: 301) { |params, _request|
    "/catalog?#{NexusCcs::SiteNavigation.whole_collection_query(params[:slug]).to_query}"
  }, constraints: ->(request) { NexusCcs::SiteNavigation.facet_value(request.path_parameters[:slug]) }
  get "help", to: "pages#help", as: :help
  # Search tips, Indigenous cultural data and Contact are no longer pages of their own: Indigenous data and Contact
  # are sections of Help, and the old addresses go there.
  get "help/search-tips", to: redirect("/catalog/advanced#advanced-search-tips-title", status: 301)
  get "help/indigenous-data", to: redirect("/help#indigenous", status: 301)
  get "contact", to: redirect("/help#contact-us", status: 301)
  get "about", to: "pages#about", as: :about
  # The pages behind the home page's Explore tiles: every object type, place, period, maker and subject
  get "browse", to: "browse#index", as: :browse
  # Category picture pages, collection and named collection pages, themes and stories (docs/categories-themes-stories.md). Every
  # list of records on them opens the search page (/catalog) with filters.
  # One Browse (the IA fixes, 24 Nov 2026, docs/ia-audit-handover.md): every way in lives under /browse. Browse by category merged into
  # /browse; a category's "See all" page is /browse/<its name>; its duplicates (object types, regions, eras) open the one page for each.
  # The Explore pages moved here from /explore. Every old address answers 301 with its query kept.
  get "browse/categories", to: redirect("/browse", status: 301)
  get "browse/categories/:slug", to: redirect(status: 301) { |params, request|
    target = { "object-types" => "/browse/object-types", "regions" => "/browse/places", "eras" => "/browse/time" }[params[:slug]] || "/browse/#{params[:slug]}"
    [ target, request.query_string.presence ].compact.join("?")
  }, constraints: { slug: /[a-z-]+/ }
  get "browse/:slug", to: "categories#show", as: :category, constraints: { slug: /classifications|materials|collections|named-collections/ }
  get "browse/time", to: "explore#time", as: :explore_time
  # the places' A to Z list and its filter (the Places hub, browse/hub) answer at the same address, asked for by their options
  get "browse/places", to: "browse#show", defaults: { slug: "places" },
                       constraints: ->(request) { request.query_parameters.keys.intersect?(%w[view letter filter page region]) }
  get "browse/places", to: "explore#places", as: :explore_places
  get "browse/colours", to: "colours#index", as: :explore_colours
  get "browse/periods", to: redirect("/browse/time", status: 301)
  %w[time places colours].each do |page|
    get "explore/#{page}", to: redirect(status: 301) { |_params, request| [ "/browse/#{page}", request.query_string.presence ].compact.join("?") }
  end
  get "browse/:kind/:slug", to: "collection_landings#show", as: :collection_landing,
                            constraints: { kind: /collections|named-collections/, slug: /[a-z0-9-]+/ }
  get "themes", to: "themes#index", as: :themes
  get "themes/:slug", to: "themes#show", as: :theme, constraints: { slug: /[a-z0-9-]+/ }
  get "stories", to: "stories#index", as: :stories
  get "stories/:slug", to: "stories#show", as: :story, constraints: { slug: /[a-z0-9-]+/ }
  get "browse/:slug", to: "browse#show", as: :browse_hub
  # Accessibility statement and privacy notice (CCS-148); placeholder wording until the University approves it
  get "accessibility", to: "pages#accessibility", as: :accessibility
  get "privacy", to: "pages#privacy", as: :privacy
  # The answer to the cookie notice (CCS-471): a POST only, so nothing here for a crawler to list
  post "cookie_notice", to: "cookie_notices#create", as: :cookie_notice

  # For crawlers (CCS-128, CCS-127): generated, so the environment's settings apply. The sitemap is an index of pages of up to 10,000 URLs.
  get "robots.txt", to: "seo#robots", format: false
  get "sitemap.xml", to: "seo#sitemap_index", format: false
  get "sitemaps/:page.xml", to: "seo#sitemap_page", as: :sitemap_page, constraints: { page: /\d+/ }, format: false
  get "llms.txt", to: "seo#llms", format: false

  # What the visitor sees for an error: Rails sends the failed request to /<status> (config.exceptions_app)
  %w[400 404 406 410 422 429 500 503].each { |code| match code, to: "errors#show", via: :all, defaults: { code: code }, as: "error_#{code}" }

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  # Liveness and readiness probes with a JSON answer (CCS-146): /healthz is the process only; /readyz also needs the database, Solr and the migrations.
  get "healthz" => "health#live", as: :liveness_check, format: false
  get "readyz" => "health#ready", as: :readiness_check, format: false

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"

  # De-bias notices: the page the record page's notice links to (DebiasTerms)
  get "language-in-our-records", to: "pages#language_in_records", as: :language_in_records

  # Galleries, embeds and oEmbed. A gallery is a list its owner has shared by an unguessable link, so galleries and the share
  # actions follow the saved records setting with the lists; the embed pages and oEmbed work either way. Only /embed/* may be framed.
  get "embed/records/:id", to: "embeds#record", as: :embed_record, constraints: { id: %r{[^/]+} }, format: false
  get "oembed", to: "oembeds#show", as: :oembed, format: false
  constraints(->(_request) { Rails.configuration.x.saved_records }) do
    get "embed/galleries/:token", to: "embeds#gallery", as: :embed_gallery, constraints: { token: /[A-Za-z0-9_-]{32}/ }, format: false
    scope "galleries/:token", constraints: { token: /[A-Za-z0-9_-]{32}/ } do
      get "", to: "galleries#show", as: :gallery
      get "citations", to: "galleries#citations", as: :citations_gallery
      post "copy", to: "galleries#copy", as: :copy_gallery
    end
    scope "lists/:list_id", constraints: { list_id: /\d+/ } do
      post "share", to: "list_shares#create", as: :list_share
      post "share/regenerate", to: "list_shares#regenerate", as: :regenerate_list_share
      delete "share", to: "list_shares#destroy"
    end
  end

  # Discovery (docs/similar-and-trending.md): the Featured and trending page, the short version the home page loads into a lazy
  # frame, and a record's Similar records (also a lazy frame, on the record page)
  get "discover", to: "discover#index", as: :discover
  get "discover/frame", to: "discover#frame", as: :discover_frame
  get "catalog/:id/similar", to: "similar#show", as: :similar, constraints: { id: %r{[^/]+} }, format: false
  # Colour (docs/colour-and-clean-up.md): browse by colour, and a record's "Looks similar" (a lazy frame on the record page)
  get "catalog/:id/looks-similar", to: "looks_similar#show", as: :looks_similar, constraints: { id: %r{[^/]+} }, format: false

  # Explore by time and by place (docs/time-and-place.md): lists that open the search with a filter

  # Entity pages (BrowseEntitiesController), under the browse index pages (BrowseController): one maker, place or subject, one century or decade
  scope "/browse", controller: "browse_entities" do
    get "periods/:slug", action: :period, as: :browse_period, constraints: { slug: /[a-z0-9-]+/ }
    get ":kind/:slug", action: :entity, as: :browse_entity, constraints: { kind: /makers|places|subjects/, slug: /[a-z0-9-]+/ }
  end
end
