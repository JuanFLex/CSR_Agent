module Reporting
  # CSR_DemandComparison, the "Data" sheet of the weekly Demand Comparison
  # report as the ETL copies it: six rows per part, told apart by
  # SNAPSHOT_DATE. The report's results (variation, status) are repeated on
  # all six; the two rows named after their dates are last week's and this
  # week's demand, one column per week.
  class DemandStaging < TrendStaging
    self.table_name = "CSR_DemandComparison"

    # The one row label that is the same every week: the two snapshot rows are
    # named after their dates.
    ROW_TYPE = "Sales"

    # The rows the portal does not read. Anything else is Sales or a snapshot.
    DERIVED_ROWS = [ "Delta in bucket", "Cummulative delta", "Cummulative delta %" ].freeze

    # What the six rows of one part share.
    PART_COLUMNS = %w[DELIVERY_ADDRESS CUSTOMER_NAME CPN COMPANY FCP_PART MANUFACTURER_PART].freeze

    # One hash per part: its Sales row's mapped columns, plus OLD_SNAPSHOT_ON,
    # NEW_SNAPSHOT_ON, OLD_WEEKS and NEW_WEEKS from its two dated rows (nil
    # when the part has none).
    def self.rows
      weeks = week_columns
      columns = (Csr::Demand::ColumnMap::COLUMNS.keys + PART_COLUMNS + [ "SNAPSHOT_DATE" ] + weeks).uniq
      relation = where.not(SNAPSHOT_DATE: DERIVED_ROWS).select(columns)

      connection.select_all(relation.to_sql).to_a.group_by { |row| row.values_at(*PART_COLUMNS) }.filter_map do |_part, rows|
        sales = rows.find { |row| row["SNAPSHOT_DATE"] == ROW_TYPE } or next
        dated = rows.filter_map { |row| (on = snapshot_on(row["SNAPSHOT_DATE"])) && [ on, row.values_at(*weeks) ] }
        # No week columns found means the table names them some other way:
        # better no weeks than 52 zeros read as a total drop.
        old, new = dated.sort_by(&:first) if dated.size == 2 && weeks.any?

        sales.slice(*Csr::Demand::ColumnMap::COLUMNS.keys).merge(
          "OLD_SNAPSHOT_ON" => old&.first, "NEW_SNAPSHOT_ON" => new&.first,
          "OLD_WEEKS" => old&.last, "NEW_WEEKS" => new&.last
        )
      end
    end

    # The 52 week columns. Their headers are dates, which the copy names by
    # position (F9, F10...), so they are found by that shape, in order, rather
    # than counted from a column that may move.
    def self.week_columns
      column_names.grep(/\AF\d+\z/i).sort_by { |name| name[1..].to_i }
    end

    # A snapshot row's label is its date: text written the American way by the
    # ETL ("10/3/2026"), ISO in the local stand-in, or a real date.
    def self.snapshot_on(value)
      return value.to_date if value.respond_to?(:strftime)

      VerticalCommitStaging.parse(value) || Date.iso8601(value.to_s[0, 10])
    rescue Date::Error
      nil
    end
  end
end
