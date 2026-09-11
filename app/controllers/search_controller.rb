require "csv"

# The portal's INPUT_PANEL: pick a search type, type a value, get the execution
# picture back. Results render inside a Turbo Frame so a search does not reload
# the page around it. The same action answers .csv with every open line.
class SearchController < ApplicationController
  CSV_COLUMNS = %i[
    cpn mpn fpn bp_name cpo cpo_pos so so_pos po baan_ordered pdd cdd miss so_status dates_condition
  ].freeze

  def index
    @search = Csr::SearchRequest.new(params)

    respond_to do |format|
      format.html { load_results unless @search.blank? }
      format.csv  { send_data lines_csv, filename: "open-orders-#{@search.value.parameterize.presence || "all"}.csv" }
    end
  end

  private

  def load_results
    @summary = @search.summary
    @keys = @search.part_keys.order(:key_value).to_a
    @context = @search.context
    @lines = @search.lines.to_a
    @escalations = @search.escalations.to_a
    @escalation_columns = chosen_columns(Csr::Escalation, :escalation_columns)
    @line_columns = chosen_columns(Csr::OsorLine, :line_columns)
  end

  # Which columns a table shows. The choice travels in the URL so a search can
  # be shared with it, and is remembered in a cookie so the next visit keeps
  # it. There is no login yet, so the browser is the user.
  def chosen_columns(model, param)
    requested = params[param] || cookies[param]&.split(",")
    chosen = model.columns_for(requested)
    cookies.permanent[param] = chosen.join(",") if params[param]
    chosen
  end

  def lines_csv
    CSV.generate do |csv|
      csv << CSV_COLUMNS
      @search.lines(limit: nil).each { |line| csv << CSV_COLUMNS.map { |column| line.public_send(column) } }
    end
  end
end
