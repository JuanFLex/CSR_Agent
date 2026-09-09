# The portal's INPUT_PANEL: pick a search type, type a value, get the execution
# picture back. Results render inside a Turbo Frame so a search does not reload
# the page around it.
class SearchController < ApplicationController
  def index
    @search = Csr::SearchRequest.new(params)

    return if @search.blank?

    @summary = @search.summary
    @keys = @search.part_keys.order(:key_value)
    @context = @search.context
    @lines = @search.lines
  end
end
