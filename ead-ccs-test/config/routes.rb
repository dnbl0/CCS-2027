# Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
Rails.application.routes.draw do
  concern :range_searchable, BlacklightRangeLimit::Routes::RangeSearchable.new
  mount Blacklight::Engine => "/"
  root to: "pages#home"
  concern :searchable, Blacklight::Routes::Searchable.new
  concern :exportable, Blacklight::Routes::Exportable.new

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
      resources :saved_searches, only: [ :index, :create, :destroy ]
      # Delete my data (CCS-148): what the site holds against the visitor's cookie, shown, then removed
      resource :my_data, only: [ :show, :destroy ], controller: "my_data", path: "my_data"
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
  resources :access_requests, only: [ :new, :create, :show ]

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
  delete "search_history/:id", to: "search_history#destroy", as: :search_history_entry, constraints: { id: /\d+/ }

  get "collections", to: redirect("/#browse-collections", status: 301)
  get "collections/:slug", to: redirect(status: 301) { |params, _request|
    "/catalog?#{NexusCcs::SiteNavigation.whole_collection_query(params[:slug]).to_query}"
  }, constraints: ->(request) { NexusCcs::SiteNavigation.facet_value(request.path_parameters[:slug]) }
  get "help", to: "pages#help", as: :help
  # Search tips, Indigenous cultural data and Contact are no longer pages of their own: Indigenous data and Contact
  # are sections of Help, and the old addresses go there.
  get "help/search-tips", to: redirect("/help", status: 301)
  get "help/indigenous-data", to: redirect("/help#indigenous", status: 301)
  get "contact", to: redirect("/help#contact-us", status: 301)
  get "about", to: "pages#about", as: :about
  # Accessibility statement and privacy notice (CCS-148); placeholder wording until the University approves it
  get "accessibility", to: "pages#accessibility", as: :accessibility
  get "privacy", to: "pages#privacy", as: :privacy

  # For crawlers (CCS-128, CCS-127): generated, so the environment's settings apply. The sitemap is an index of pages of up to 10,000 URLs.
  get "robots.txt", to: "seo#robots", format: false
  get "sitemap.xml", to: "seo#sitemap_index", format: false
  get "sitemaps/:page.xml", to: "seo#sitemap_page", as: :sitemap_page, constraints: { page: /\d+/ }, format: false
  get "llms.txt", to: "seo#llms", format: false

  # What the visitor sees for an error: Rails sends the failed request to /<status> (config.exceptions_app)
  %w[400 404 406 422 429 500 503].each { |code| match code, to: "errors#show", via: :all, defaults: { code: code }, as: "error_#{code}" }

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
end
