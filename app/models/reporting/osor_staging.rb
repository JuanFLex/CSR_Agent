module Reporting
  # CSR_OSOR_AMERICAS, as loaded twice a day by the DBA's truncate+insert.
  #
  # Nothing here is read live by the portal. Csr::Osor::Ingest copies it into a
  # snapshot first, so a load in progress never shows up as an empty portal.
  class OsorStaging < Base
    TABLES = {
      Csr::DEFAULT_REGION => "CSR_OSOR_AMERICAS"
      # "Asia" and "Europe" follow the same shape — build book Vol.2 §19.
    }.freeze

    self.table_name = TABLES.fetch(Csr::DEFAULT_REGION)

    def self.for_region(region)
      table = TABLES.fetch(region) { raise ArgumentError, "No OSOR staging table for region #{region.inspect}" }
      Class.new(self) { self.table_name = table }
    end

    # How fresh the staging table is, from its own column. Reading this rather
    # than adding a trigger is what lets the DBA's load process stay untouched.
    def self.watermark
      Csr::Osor::ColumnMap.to_time(maximum(:lastupdate))
    end
  end
end
