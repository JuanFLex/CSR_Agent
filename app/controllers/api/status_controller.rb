module Api
  # GET /api/status — the SUMMARY execution block for whatever was searched.
  class StatusController < BaseController
    def show
      render_envelope(execution: search_request.summary)
    end
  end
end
