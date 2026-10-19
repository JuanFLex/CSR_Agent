module Reporting
  # CSR_DemandComparison, the "Data" sheet of the weekly Demand Comparison
  # report as the ETL copies it: six rows per part, told apart by
  # SNAPSHOT_DATE. The report's results (variation, status) are repeated on
  # all six, so one of them is all the portal reads.
  class DemandStaging < TrendStaging
    self.table_name = "CSR_DemandComparison"

    # The one row label that is the same every week: the two snapshot rows are
    # named after their dates.
    ROW_TYPE = "Sales"

    def self.rows
      relation = where(SNAPSHOT_DATE: ROW_TYPE).select(Csr::Demand::ColumnMap::COLUMNS.keys)
      connection.select_all(relation.to_sql).to_a
    end
  end
end
