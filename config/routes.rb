Rails.application.routes.draw do
  root "search#index"
  get "search" => "search#index", as: :search  # same page; carries .csv for the export

  # No /api yet: build book Vol.2 §21 specifies one, but nothing consumes it.
  # The services behind it (Csr::SearchRequest and friends) are what an API
  # would be built on, the day a caller exists.

  get "up" => "rails/health#show", as: :rails_health_check
end
