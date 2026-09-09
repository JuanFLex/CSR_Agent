Rails.application.routes.draw do
  root "search#index"

  # Endpoint names follow the Web/API mapping in build book Vol.2 §21 so the
  # document keeps describing the system after the Excel is retired.
  namespace :api do
    resources :keys,   only: :index    # key resolution service  (KEY_LIST)
    resources :orders, only: :index    # osor_lines              (tOSOR)
    resource  :status, only: :show, controller: "status"  # status aggregation (SUMMARY)
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
