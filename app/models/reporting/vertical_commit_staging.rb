module Reporting
  # CS_tempVerticalCommit, read for one thing: the Saturday the workbook's
  # weeks start on. The wide sheets lose the dates of their header row on the
  # way in; this sheet keeps a date on every row, and all three start on the
  # same week.
  class VerticalCommitStaging < Base
    self.table_name = "CS_tempVerticalCommit"

    def self.first_week
      distinct.pluck(:DATE).filter_map { |value| parse(value) }.min
    end

    # DATE is text, written the American way: "1/2/2027" is January 2. It
    # shares the column with the words Past and Future and the sheet's own
    # header. Ruby's own parsers read a slashed date as day/month, hence the
    # explicit format.
    def self.parse(value)
      Date.strptime(value.to_s.strip, "%m/%d/%Y")
    rescue Date::Error
      nil
    end
  end
end
