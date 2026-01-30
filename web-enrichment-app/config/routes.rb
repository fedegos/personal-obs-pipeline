Rails.application.routes.draw do
  devise_for :users
  resources :category_rules
  resources :audit_corrections, only: [ :index, :edit, :update, :show ]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  get "transactions", to: "transactions#index", as: "transactions"
  patch "transactions/:id/approve", to: "transactions#approve", as: "approve_transaction"

  # Redirigir la raíz a las transacciones
  root "transactions#index"



  # Gestión de Archivos
  get "upload", to: "source_files#index", as: "upload"
  post "source_files", to: "source_files#create", as: "source_files"
end
