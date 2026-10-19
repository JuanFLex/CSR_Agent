module Csr
  module Demand
    # Copies one row per part of CSR_DemandComparison into a new snapshot.
    class Ingest < SourceIngest
      def initialize(staging: Reporting::DemandStaging, **options)
        super(**options)
        @staging = staging
      end

      private

      attr_reader :staging

      def source_type = "demand"

      def load_rows(snapshot)
        count = staging.count
        inserted = 0
        rejected = 0

        staging.rows.each_slice(INSERT_BATCH) do |rows|
          attribute_sets = rows.map { |row| ColumnMap.cast(row) }
          key_ids, key_values = resolve_part_keys(attribute_sets)
          now = Time.current

          records = attribute_sets.zip(key_values).map do |attrs, key_value|
            rejected += 1 if key_value.nil?
            attrs.merge(snapshot_id: snapshot.id, part_key_id: key_ids[key_value], created_at: now, updated_at: now)
          end

          DemandLine.insert_all!(records)
          inserted += records.size
        end

        snapshot.update!(row_count: inserted, rejected_count: rejected)

        # A table refilled while it was being read gives a mix of two loads.
        raise "#{staging.table_name} changed while it was being read" unless staging.count == count
      end

      def activation_message(snapshot)
        "Activated #{snapshot.row_count} demand rows (#{snapshot.rejected_count} without a key)"
      end
    end
  end
end
