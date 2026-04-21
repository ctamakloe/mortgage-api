Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :mortgage_applications, only: [:create, :show]
    end
  end
end
