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
      registrations: "api/v1/registrations"
    },
    defaults: { format: :json }

  root "wines#index"

  resources :wines
  resources :producers
  resources :vintages
  resources :taste_parameters
  resources :wine_profiles
  resources :reviews
  resources :wine_taste_parameters
  resources :test_parameters

  namespace :api do
    namespace :v1 do
      resources :producers
      resources :wines do
        resources :vintages, only: [] do
          resources :reviews, only: [:index, :create]
        end
      end
      resources :reviews, only: [:show, :update, :destroy] do
        collection do
          get :my_reviews
        end
      end
      resources :wine_profiles do
        collection do
          get :search
        end
      end
      resources :taste_parameters

      get "me", to: "users#me"
    end
  end
end
