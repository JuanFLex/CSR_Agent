class Admin::UsageController < ApplicationController
  # :all as a Symbol, not [:all] — see the comment in Admin::UsersController.
  access admin: :all

  def index
    report = Usage.report(since: requested_since)

    @since = report.since
    @summary = report.summary
    @by_week = report.by_week
    @by_user = report.by_user
    @by_search_type = report.by_search_type
    @no_results_rate = report.no_results_rate
    @never_searched = report.never_searched
  end

  private

  # The period can be changed from the UI, but only with an ISO date: the
  # value ends up in a SQL placeholder, and even then nothing that doesn't
  # match this exact shape is passed through.
  def requested_since
    raw = params[:since].to_s
    raw.match?(/\A\d{4}-\d{2}-\d{2}\z/) ? raw : Usage.config.since
  end
end
