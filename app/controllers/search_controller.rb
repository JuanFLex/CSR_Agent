require "csv"

# The portal's INPUT_PANEL: pick a search type, type a value, get the execution
# picture back. Results render inside a Turbo Frame so a search does not reload
# the page around it. The same action answers .csv with every open line.
class SearchController < ApplicationController
  # Any signed-in user. PeterGate denies nothing without an `access` call; this
  # states the intent instead of relying on that.
  access user: :all

  def index
    @search = Csr::SearchRequest.new(params)

    respond_to do |format|
      format.html { load_results unless @search.blank? }
      format.csv  { export_csv }
    end
  end

  private

  def load_results
    @summary = @search.summary
    @keys = @search.part_keys.order(:key_value).to_a
    @context = @search.context
    @buffer = @search.buffer
    @commit = @search.commit
    @demand = @search.demand
    @pages = (@summary[:open_lines].to_f / Csr::SearchRequest::LINES_PER_PAGE).ceil
    @page = params[:page].to_i.clamp(1, [ @pages, 1 ].max)
    @lines = @search.lines(page: @page).to_a
    @escalations = @search.escalations.to_a
    @escalation_columns = chosen_columns(Csr::Escalation, :escalation_columns)
    @line_columns = chosen_columns(Csr::OsorLine, :line_columns)
    log_search("search") unless params[:page].present?
  end

  # Open orders, or the escalations with ?table=escalations. Each carries the
  # columns its table was showing.
  def export_csv
    esc = params[:table] == "escalations"
    model, param = esc ? [ Csr::Escalation, :escalation_columns ] : [ Csr::OsorLine, :line_columns ]
    records = esc ? @search.escalations : @search.lines(limit: nil)
    send_data table_csv(model, chosen_columns(model, param), records),
              filename: "#{esc ? "escalations" : "open-orders"}-#{@search.value.parameterize.presence || "all"}.csv"
    log_search("export")
  end

  # The unit of usage this app reports on is a search, not a page view: one
  # row per non-blank HTML search and one per CSV export. Logging must never
  # break the search it is logging, so a failure here only ever costs the
  # usage report a row, not the response.
  def log_search(kind)
    return if @search.blank?

    Csr::SearchLog.create!(
      user: current_user, kind: kind, search_type: @search.search_type,
      value: @search.value, keys_found: @search.summary[:combos_found]
    )
  rescue StandardError => e
    Rails.logger.error("[SearchLog] #{e.message}")
  end

  # Which columns a table shows. The choice travels in the URL so a search can
  # be shared with it, and is remembered in a cookie so the next visit keeps
  # it — per browser, same as before login existed.
  def chosen_columns(model, param)
    requested = params[param] || cookies[param]&.split(",")
    chosen = model.columns_for(requested)
    cookies.permanent[param] = chosen.join(",") if params[param]
    chosen
  end

  # The export is the table: same columns, same order, same labels as whoever
  # asked for it sees on screen.
  #
  # ponytail: builds the whole CSV in memory — a search is a part number, not a
  # catalogue. Stream it (ActionController::Live) if an export ever gets big
  # enough to notice.
  def table_csv(model, columns, records)
    CSV.generate do |csv|
      csv << columns.map { |column| model::COLUMNS[column] }
      records.each { |record| csv << columns.map { |column| record.public_send(column) } }
    end
  end
end
