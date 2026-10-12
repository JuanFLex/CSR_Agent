module Reporting
  # CSR_CustomerCommitment, the "Customer Commitment" sheet of
  # CS_Trend_Forecast.xlsx as the ETL copies it: eight rows per part, one of
  # which is the commit balance. Company 702 only, so every row is Americas.
  #
  # The sheet's first row is almost empty, so the copy had nothing to name
  # most columns after: they are NoName, NoName1... and F8, F18... by
  # position. Csr::Commit::ColumnMap says which is which.
  class CommitStaging < TrendStaging
    self.table_name = "CSR_CustomerCommitment"

    TYPE_COLUMN = "NoName14"
    ROW_TYPE = "Balance"
    COLUMN_MAP = Csr::Commit::ColumnMap

    LABELS = {
      "NoName2" => "Customer",
      "NoName3" => "Delivery Address",
      "NoName4" => "CPN",
      "NoName5" => "Part",
      "NoName6" => "MPN"
    }.freeze
  end
end
