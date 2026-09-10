module Csr
  module Fet
    # Copies the open escalations of CSR_FET into a new snapshot.
    class Ingest < SourceIngest
      def initialize(staging: Reporting::FetStaging, **options)
        super(**options)
        @staging = staging
      end

      private

      attr_reader :staging

      def source_type = "escalation"

      # CSR_FET carries no load timestamp, so UPDATED_DATE alone cannot tell a
      # fresh load from a repeat: it is a business date, at day granularity, and
      # a reload that changes nothing leaves it where it was. The pair
      # (latest UPDATED_DATE, open row count) can: if neither moved, there is
      # nothing to copy. Both are single aggregates, so polling stays cheap.
      def nothing_new?(previous, watermark)
        super && previous.row_count == staging.open_escalations.count
      end

      def load_rows(snapshot)
        relation = staging.open_escalations.select(ColumnMap::SELECT_COLUMNS)
        rows = staging.connection.select_all(relation.to_sql).to_a
        inserted = 0

        rows.each_slice(INSERT_BATCH) do |slice|
          now = Time.current
          records = slice.map do |row|
            ColumnMap.cast(row).merge(snapshot_id: snapshot.id, created_at: now, updated_at: now)
          end

          Escalation.insert_all!(records) if records.any?
          inserted += records.size
        end

        snapshot.update!(row_count: inserted)
      end

      def activation_message(snapshot)
        "Activated #{snapshot.row_count} open escalations"
      end
    end
  end
end
