module Reporting
  # CS_tempTrendReportWeek: the Saturday CS_Trend_Forecast.xlsx's weeks start
  # on, which the ETL reads off the Buffer sheet's header (the cell after
  # "Past"). The wide sheets lose their header on the way in, and the vertical
  # sheet's dates cannot stand in: in 4 of the workbooks WK19..WK44 (WK44
  # among them) they start a week early.
  class ReportWeekStaging < Base
    self.table_name = "CS_tempTrendReportWeek"

    # One row per load; two different weeks mean a half-done load, so no week.
    def self.first_week
      weeks = distinct.pluck(:REPORT_WEEK)
      weeks.first if weeks.one?
    end
  end
end
