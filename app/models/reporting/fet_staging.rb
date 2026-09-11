module Reporting
  # CSR_FET, the escalation feed. The DBA's ETL brings company 702 only, so
  # every row is Americas; Asia (812) and Europe (904) are not loaded yet.
  class FetStaging < Base
    self.table_name = "CSR_FET"

    # A closed escalation is history. The portal answers "what is on fire now",
    # and the table is right there the day someone needs the rest.
    scope :open_escalations, -> { where.not(ESCALATION_STATUS: "CLOSED") }

    # CSR_FET has no load timestamp: UPDATED_DATE is a business date, at day
    # granularity. It is good enough to record as freshness, but not to tell a
    # fresh load from a repeat — see Csr::Fet::Ingest.
    def self.watermark
      Csr::ColumnCast.to_time(open_escalations.maximum(:UPDATED_DATE))
    end
  end
end
