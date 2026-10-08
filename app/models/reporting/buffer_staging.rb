module Reporting
  # CSR_BUFFER_READINESS, the weekly buffer projection: one row per part and
  # week, refilled by the DBA's ETL from CS_Trend_Forecast.xlsx. Its shape and
  # the fill are in script/sql/csr_buffer_readiness.sql. Company 702 only, so
  # every row is Americas.
  class BufferStaging < Base
    self.table_name = "CSR_BUFFER_READINESS"

    # The fill stamps every row of a load with the same LOADED_AT.
    def self.watermark
      Csr::ColumnCast.to_time(maximum(:LOADED_AT))
    end

    # The table is ~4.7k parts x 51 weeks. The ingest reads it a week at a
    # time, so it holds one week in memory rather than a quarter of a million
    # rows.
    def self.bucket_dates
      distinct.order(:BUCKET_DATE).pluck(:BUCKET_DATE)
    end

    def self.rows_for(bucket_date)
      relation = where(BUCKET_DATE: bucket_date).select(Csr::Buffer::ColumnMap::SELECT_COLUMNS)
      connection.select_all(relation.to_sql).to_a
    end
  end
end
