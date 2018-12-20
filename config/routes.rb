Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root 'home#index'
  get 'pwa', to: 'home#pwa'

  namespace :api do
    resources :deliveries, only: %i(index)
  end
end
