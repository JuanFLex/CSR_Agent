Rails.application.routes.draw do
  devise_for :users

  root "search#index"
  # The same page; carries .csv for the export. A :view is one section of the
  # left menu, reached from the menu rather than from the search box.
  get "search(/:view)" => "search#index", as: :search,
      constraints: { view: Regexp.union(SearchController::VIEWS.keys) }

  # No /api yet: build book Vol.2 §21 specifies one, but nothing consumes it.
  # The services behind it (Csr::SearchRequest and friends) are what an API
  # would be built on, the day a caller exists.

  namespace :admin do
    resources :users, except: [ :show ]
    get "usage", to: "usage#index"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
