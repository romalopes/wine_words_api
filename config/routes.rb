Rails.application.routes.draw do
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
    end
  end
end