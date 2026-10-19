module Reporting
  # CSR_CustomerCommitment, the "Customer Commitment" sheet of
  # CS_Trend_Forecast.xlsx as the ETL copies it: eight rows per part, one of
  # which is the commit balance. Company 702 only, so every row is Americas.
  #
  # The sheet's first row is almost empty, so the copy names every column by
  # position, F1 to F71, and keeps the sheet's header rows as data.
  # Csr::Commit::ColumnMap says which is which.
  class CommitStaging < TrendStaging
    self.table_name = "CSR_CustomerCommitment"

    TYPE_COLUMN = "F16"
    ROW_TYPE = "Balance"
    COLUMN_MAP = Csr::Commit::ColumnMap

    LABELS = {
      "F3" => "Customer",
      "F4" => "Delivery Address",
      "F5" => "CPN",
      "F6" => "Part",
      "F7" => "MPN"
    }.freeze
  end
end
