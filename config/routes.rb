Rails.application.routes.draw do
  # Rails' default health check (Rails::HealthController). `render.yaml`
  # points Render's healthCheckPath here, so a deploy is only reported live
  # once Puma is actually serving requests — Thruster binds its port (:80)
  # before Puma finishes booting, which otherwise produces boot-window 502s.
  get "up" => "rails/health#show", as: :rails_health_check

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

  # Email verification (token from the link in the verification email).
  get "api/v1/email-verifications/:token", to: "api/v1/email_verifications#show"
  post "api/v1/email-verifications/resend", to: "api/v1/email_verifications_resend#create"

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
  post "user_roles/impersonate/:user_id", to: "user_roles#start_impersonation", as: :start_impersonation
  delete "user_roles/impersonate", to: "user_roles#stop_impersonation", as: :stop_impersonation

  namespace :api do
    namespace :v1 do
      get "health", to: "health#index"
      get "health/detailed", to: "health#detailed"
      get "health/search_index", to: "health#search_index"

      # --- Diagnostics: health e-mail tool (issue #167) ------------------------- #
      # `email_transport` is public (no auth) so the React ApiHealth page can
      # render the email-status row without a token. `send_test_email` is
      # admin-only (authenticate_admin!).
      get  "health/email/transport",    to: "health#email_transport",    as: :health_email_transport
      post "health/email/test",         to: "health#send_test_email",    as: :health_send_test_email


      # Private test-access gate (see TestAccessToken): password -> signed
      # token; token verification for the SPA on boot.
      post "test_access", to: "test_access#create"
      get "test_access", to: "test_access#show"
      get "logs", to: "logs#index"
      get "logs/audit", to: "logs#audit_logs"
      get "logs/:id", to: "logs#show"
      post "images", to: "images#create"
      delete "images/:id", to: "images#destroy"
      patch "images/reorder", to: "images#reorder"
      patch "images/:id/primary", to: "images#set_primary"
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
        resource :like, only: [:create, :destroy], controller: "wine_likes"
        resources :comments, only: [:index, :create], controller: "wine_comments"
        resources :vintages, only: [:create] do
          resources :reviews, only: [:index, :create]
        end
      end
      resources :reviews, only: [:index, :show, :update, :destroy] do
        collection do
          get :my_reviews
          get :grouped
        end
        member do
          # "More reviews" footer on the review page: newest reviews sharing this
          # one's categories.
          get :related
        end
        resource :like, only: [:create, :destroy], controller: "review_likes"
        resources :comments, only: [:index, :create], controller: "review_comments"
      end
      resources :sources, only: [:index]
      resources :articles, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get :my_articles
          get :grouped
        end
        member do
          # "More articles" footer on the article page: newest articles sharing
          # this one's categories.
          get :related
        end
        resource :like, only: [:create, :destroy], controller: "article_likes"
        resources :comments, only: [:index, :create], controller: "article_comments"
      end
      resources :article_projects, only: [:index, :show, :create, :update, :destroy] do
        collection { get :lookup }
        resources :article_project_vintages, only: [] do
          resources :notebooks,
                    controller: "article_project_notebooks",
                    param: :notebook_id,
                    only: [:index, :create, :show, :update, :destroy] do
            member { post :review, action: :create_review }
          end
        end
      end
      # Comments that are not nested under a commentable: replying to a comment,
      # and editing / soft-deleting one. A reply inherits its commentable from the
      # parent comment, so the client never supplies a commentable_type/id.
      resources :comments, only: [:update, :destroy] do
        resources :replies, only: [:create], controller: "comments", action: :create_reply
      end
      resources :categories, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get :counts
          patch :reorder
        end
        member do
          post :link_wine
          post :link_producer
          post :link_review
          post :link_article
        end
      end
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

      # --- Wine packages: the reviewing workflow ---------------------------
      # CRUD plus explicit workflow actions — never a free-form status write.
      resources :wine_packages do
        member do
          post :mark_arrived
          post :mark_in_transit
          post :mark_completed
          post :reopen
          post :cancel
          post :accept
          post :reject
        end

        # The wine lines of a package (nested CRUD; create_review starts the
        # ordinary review flow from a line).
        resources :items,
                  controller: "wine_package_items",
                  only: [:create, :update, :destroy] do
          member { post :create_review }
        end

        # Tracking is a singleton per package: read it, upsert it, refresh it
        # from the resolved carrier provider.
        resource :shipment_tracking,
                 controller: "shipment_trackings",
                 only: [:show, :update] do
          post :refresh
        end
      end

      # The signed-in user's own notifications (deadline reminders).
      resources :notifications, only: [:index] do
        collection { patch :mark_all_read }
        member { patch :mark_read }
      end

      # Billing — checkout session and customer portal (authenticated).
      post "billing/checkout", to: "billing#checkout"
      post "billing/portal", to: "billing#portal"
      # Reconcile a Checkout Session after Stripe redirects back (no webhook needed).
      post "billing/confirm", to: "billing#confirm"
      # Unified plan change (upgrade pays the prorated difference; downgrade is
      # scheduled effective at the next renewal).
      post "billing/change/preview", to: "billing#change_preview"
      post "billing/change/confirm", to: "billing#change_confirm"

      # Stripe webhook (no authentication — verified via webhook signature).
      post "webhooks/stripe", to: "webhooks#stripe"

      # --- Social authentication -------------------------------------------
      # Provider sign-in. The credential (provider ID/access token) is posted
      # here and verified server-side; the endpoint signs the resolved User in
      # with the ordinary Devise scope, so the JWT and response payload are
      # identical to email/password sign-in (see SocialAuthController).
      %w[google apple microsoft facebook].each do |provider|
        post "auth/#{provider}",
             to: "social_auth#create",
             defaults: { provider: provider }
      end

      # Connected sign-in methods for the authenticated User. Linking adds an
      # authentication identity only — never a User, Account or subscription.
      get "auth/identities", to: "user_identities#index"
      post "auth/identities/:provider", to: "user_identities#create"
      delete "auth/identities/:id", to: "user_identities#destroy"

      get "me", to: "users#me"
      get "stats", to: "stats#index"

      resources :users, only: [] do
        collection { get :search }
        member { patch :assign_roles; patch :assign_subscription }
      end
      get "roles", to: "users#roles"

      # User impersonation (admin only): start, stop, and status check.
      # A single resource gives us create (POST /impersonations),
      # destroy (DELETE /impersonations), and a custom status endpoint.
      resource :impersonation, controller: "impersonations", only: [:create, :destroy, :show] do
        get :status, on: :collection, action: :show
      end

      # Global configuration (admin only): singleton settings for the
      # Configuration page — audit-log persistence toggle plus the email-test
      # settings. Custom (user-added) settings are managed through the nested
      # settings resource.
      resource :configuration, controller: "configurations", only: [:show, :update] do
        resources :settings, only: [:index, :create, :update, :destroy], module: "configuration"
      end

      get "account", to: "accounts#show"
      patch "account", to: "accounts#update"
      patch "account/password", to: "accounts#update_password"

      resources :subscriptions, only: [:index, :show, :create, :update, :destroy]
    end
  end
end
