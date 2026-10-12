module Reporting
  # CS_tempTrendBufferReadinessProjection, the "CS - Buffer Readiness
  # Projection" sheet of CS_Trend_Forecast.xlsx as the ETL copies it for the
  # Tableau trend report: eight rows per part, one of which is the projected
  # balance against safety stock. Company 702 only, so every row is Americas.
  class BufferStaging < TrendStaging
    self.table_name = "CS_tempTrendBufferReadinessProjection"

    TYPE_COLUMN = "TYPE"
    ROW_TYPE = "Balance vs SS (Buffer Stock)"
    COLUMN_MAP = Csr::Buffer::ColumnMap

    LABELS = {
      "FCP_PART"          => "FCP Part",
      "FCP_SITE"          => "FCP Site",
      "MANUFACTURER_PART" => "Manufacturer Part",
      "SUPPLIER_NAME"     => "Supplier Name",
      "CUSTOMER_ID"       => "Customer ID",
      "DELIVERY_ADDRESS"  => "Delivery Address",
      "CPN"               => "CPN",
      "TYPE"              => "Type"
    }.freeze
  end
end
