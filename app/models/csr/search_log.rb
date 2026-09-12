module Csr
  # One row per search or CSV export a signed-in user runs — the unit of
  # usage for this portal (there is no chat to count questions in).
  class SearchLog < ApplicationRecord
    KINDS = %w[search export].freeze

    belongs_to :user

    validates :kind, inclusion: { in: KINDS }
  end
end
