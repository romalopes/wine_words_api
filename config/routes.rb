Rails.application.routes.draw do
  devise_for :users,
    path: "api/v1/auth",
    path_names: {
      sign_in: "sign_in",
      sign_out: "sign_out",
      registration: "sign_up"
    },
    controllers: {
      sessions: "api/v1/sessions",
      registrations: "api/v1/registrations",
      passwords: "api/v1/passwords"
    },
    defaults: { format: :json }

  root "web/dashboard#index"

  get "login", to: "web/sessions#new"
  post "login", to: "web/sessions#create"
  delete "logout", to: "web/sessions#destroy"
  get "signup", to: "web/registrations#new"
  post "signup", to: "web/registrations#create"

  # SPA-style public pages matching the React app's routes.
  get "quiz", to: "web/quiz#index"
  get "quiz/search", to: "web/quiz#search", defaults: { format: :json }
  get "finder", to: "web/finder#index"
  get "finder/matches", to: "web/finder#matches", as: :finder_matches
  get "search", to: "web/search#index"
  get "search/results", to: "web/search#results", as: :search_results, defaults: { format: :json }
  get "about", to: "web/about#index"
  get "subscribe", to: "web/subscribe#index"
  post "subscribe", to: "web/subscribe#create"
  get "account", to: "web/accounts#show", as: :account
  patch "account", to: "web/accounts#update"
  patch "account/password", to: "web/accounts#update_password"

  get "wines/:wine_id/vintages/:vintage_id/reviews", to: "wines#vintage_reviews",
      defaults: { format: :json }
  resources :wines do
    collection do
      get :search
    end
    member do
      patch :purge_image
    end
  end
  resources :producers do
    member do
      post :link_wine
    end
  end
  resources :vintages
  resources :taste_parameters
  resources :wine_profiles
  resources :reviews do
    member do
      patch :purge_image
    end
  end
  resources :articles do
    member do
      patch :purge_image
      patch :add_review
      patch :remove_review
      patch :toggle_review_status
    end
  end
  resources :categories do
    collection { patch :reorder }
    member { post :link_wine }
  end
  resources :tags
  resources :countries do
    member { post :link_producer }
  end
  resources :regions do
    member do
      post :link_wine
      post :link_producer
    end
  end
  resources :grapes do
    collection { get :search }
    member do
      post :link_wine
      post :link_producer
      post :producers
    end
  end
  resources :wine_taste_parameters
  resources :test_parameters

  get "user_roles", to: "user_roles#index"
  patch "user_roles/:user_id", to: "user_roles#update", as: :user_role

  namespace :api do
    namespace :v1 do
      get "health", to: "health#index"
      get "health/detailed", to: "health#detailed"
      get "logs", to: "logs#index"
      get "logs/audit", to: "logs#audit_logs"
      get "logs/:id", to: "logs#show"
      post "images", to: "images#create"
      delete "images/:id", to: "images#destroy"
      resources :producers do
        collection do
          get :search
        end
        member do
          post :logo, action: :attach_logo
          delete :logo, action: :remove_logo
          post :link_wine
          post :link_producer
        end
      end
      resources :wines do
        collection do
          get :search
          get :grouped
          get :advanced_search
        end
        resources :vintages, only: [:create] do
          resources :reviews, only: [:index, :create]
        end
      end
      resources :reviews, only: [:index, :show, :update, :destroy] do
        collection do
          get :my_reviews
          get :grouped
        end
      end
      resources :articles, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get :my_articles
          get :grouped
        end
      end
      resources :categories, only: [:index] do
        collection do
          patch :reorder
          get :counts
        end
      end
      get "categories/:id", to: "categories#show"
      post "categories", to: "categories#create"
      patch "categories/:id", to: "categories#update"
      delete "categories/:id", to: "categories#destroy"
      resources :wine_profiles do
        collection do
          get :search
        end
      end
            resources :taste_parameters
      resources :grapes do
        collection { get :search }
        member do
          post :link_wine
          post :link_producer
        end
      end
      resources :countries do
        member { post :link_producer }
      end
      resources :regions do
        collection do
          get :tree
        end
        member do
          post :link_wine
          post :link_producer
        end
      end
      resources :categories, only: [:index] do
        collection do
          patch :reorder
          get :counts
        end
        member do
          post :link_wine
          post :link_producer
          post :link_review
          post :link_article
        end
      end

      # Billing — checkout session and customer portal (authenticated).
      post "billing/checkout", to: "billing#checkout"
      post "billing/portal", to: "billing#portal"
      # Reconcile a Checkout Session after Stripe redirects back (no webhook needed).
      post "billing/confirm", to: "billing#confirm"

      # Stripe webhook (no authentication — verified via webhook signature).
      post "webhooks/stripe", to: "webhooks#stripe"

      get "me", to: "users#me"
      get "stats", to: "stats#index"

      resources :users, only: [] do
        collection { get :search }
        member { patch :assign_roles; patch :assign_subscription }
      end
      get "roles", to: "users#roles"

      get "account", to: "accounts#show"
      patch "account", to: "accounts#update"
      patch "account/password", to: "accounts#update_password"

      resources :subscriptions, only: [:index, :show, :create, :update, :destroy]
    end
  end
end
