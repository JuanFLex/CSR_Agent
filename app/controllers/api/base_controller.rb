module Api
  class BaseController < ActionController::API
    private

    def search_request
      @search_request ||= Csr::SearchRequest.new(params)
    end

    def render_envelope(payload)
      render json: {
        query: { search_type: search_request.search_type, value: search_request.value },
        **payload,
        meta: freshness
      }
    end

    # Every response says which snapshot answered it. Two calls a minute apart
    # can legitimately disagree if a load landed between them, and the caller
    # needs to be able to tell that from a bug.
    def freshness
      snapshot = search_request.snapshot
      return { snapshot_id: nil, source_file: nil, fresh_as_of: nil } if snapshot.nil?

      { snapshot_id: snapshot.id, source_file: snapshot.source_file, fresh_as_of: snapshot.fresh_as_of }
    end
  end
end
