Rails.application.routes.draw do
  # Public site (overview §4.4); the public site work package adds the controllers.
  root "artworks#index"
  get "obra/:slug", to: "artworks#show", as: :artwork
  get "torn-posters", to: "torn_posters#index", as: :torn_posters
  get "sobre-mi", to: "pages#about", as: :about
  get "contacto", to: "pages#contact", as: :contact
  get "sitemap.xml", to: "sitemaps#show", as: :sitemap, defaults: { format: "xml" }
  get "robots.txt", to: "robots#show", as: :robots, defaults: { format: "text" }

  # Error pages, rendered in the site's layout through config.exceptions_app = routes.
  match "404", to: "errors#not_found", via: :all
  match "500", to: "errors#internal_error", via: :all

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Log in and out. There is no sign-up and no password recovery.
  resource :session, only: %i[new create destroy]

  # The back office: every route here requires login.
  namespace :admin do
    root "artworks#index"

    # Works are found by slug (Artwork#to_param); show redirects to edit. PATCH …/move?direction=up|down
    # moves a work or a detail one place.
    resources :artworks do
      patch :move, on: :member

      # Detail photos, on the work's edit page: several uploaded at once.
      resources :details, controller: "artwork_details", only: %i[create destroy] do
        patch :move, on: :member
      end
    end

    # Torn Posters: uploaded many at once (create), edited together in one table (bulk_update), and one by
    # one on their own page to replace the photo (edit, update). Show redirects to edit.
    resources :torn_posters, path: "torn-posters", except: :new do
      patch :move, on: :member
      patch :bulk_update, on: :collection
    end
  end
end
