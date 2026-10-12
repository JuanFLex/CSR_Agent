module Reporting
  # A sheet of CS_Trend_Forecast.xlsx as the ETL copies it: several rows per
  # part, one column per week, and a `loaded_at` stamp on every row.
  #
  # The copy is by position and takes the sheet's own header row along as one
  # more row. A subclass names the column that says what a row is
  # (TYPE_COLUMN), the one kind of row the portal reads (ROW_TYPE), the map of
  # its columns (COLUMN_MAP) and what the header row has to say in them
  # (LABELS).
  class TrendStaging < Base
    self.abstract_class = true

    def self.watermark
      Csr::ColumnCast.to_time(maximum(:loaded_at))
    end

    # Seconds since the table was loaded, by the reporting server's own clock.
    # Both ends come back in one row and are read the same way, so no time
    # zone has to be known here.
    def self.age
      loaded_at, now = pluck(Arel.sql("MAX(loaded_at)"), Arel.sql("CURRENT_TIMESTAMP")).first
                         .map { |value| Csr::ColumnCast.to_time(value) }

      now - loaded_at if loaded_at && now
    end

    def self.rows
      relation = where(self::TYPE_COLUMN => self::ROW_TYPE).select(self::COLUMN_MAP.select_columns)
      connection.select_all(relation.to_sql).to_a
    end

    # A column added to the workbook moves every column after it, and the copy
    # goes through without an error. The header row is the one thing in the
    # table that says where the columns really are, so it has to be there and
    # agree with the map. It cannot vouch for the week columns: their header
    # cells are dates, which the copy turns into NULL.
    def self.layout_ok?
      where(self::LABELS).exists?
    end
  end
end
