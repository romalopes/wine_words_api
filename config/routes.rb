Rails.application.routes.draw do
  get "/health", to: "health#show"
  devise_for :users,
    path: "api/v1/auth",
    path_names: {
      sign_in: "sign_in",
      sign_out: "sign_out",
      registration: "sign_up"
    },
    controllers: {
      sessions: "api/v1/sessions",
      registrations: "api/v1/registrations"
    },
    defaults: { format: :json }

  root "web/dashboard#index"

  get "login", to: "web/sessions#new"
  post "login", to: "web/sessions#create"
  delete "logout", to: "web/sessions#destroy"
  get "signup", to: "web/registrations#new"
  post "signup", to: "web/registrations#create"

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
  resources :producers
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
  resources :categories
  resources :tags
  resources :wine_taste_parameters
  resources :test_parameters

  get "user_roles", to: "user_roles#index"
  patch "user_roles/:user_id", to: "user_roles#update", as: :user_role

  namespace :api do
    namespace :v1 do
      post "images", to: "images#create"
      delete "images/:id", to: "images#destroy"
      resources :producers do
        collection do
          get :search
        end
      end
      resources :wines do
        collection do
          get :search
        end
        resources :vintages, only: [:create] do
          resources :reviews, only: [:index, :create]
        end
      end
      resources :reviews, only: [:index, :show, :update, :destroy] do
        collection do
          get :my_reviews
        end
      end
      resources :articles, only: [:index, :show, :create, :update, :destroy]
      resources :categories, only: [:index]
      resources :wine_profiles do
        collection do
          get :search
        end
      end
      resources :taste_parameters

      get "me", to: "users#me"

      resources :users, only: [] do
        collection { get :search }
        member { patch :assign_roles }
      end
      get "roles", to: "users#roles"
    end
  end
end
