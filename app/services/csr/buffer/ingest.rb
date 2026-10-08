module Csr
  module Buffer
    # Copies CSR_BUFFER_READINESS into a new snapshot, a week at a time.
    #
    # A buffer row carries CPN and MPN, so it resolves to a CPN|MPN key the
    # same way an order line does, and a part with a buffer but no open order
    # still gets its key.
    class Ingest < SourceIngest
      def initialize(staging: Reporting::BufferStaging, **options)
        super(**options)
        @staging = staging
      end

      private

      attr_reader :staging

      def source_type = "buffer"

      def load_rows(snapshot)
        inserted = 0
        rejected = 0

        staging.bucket_dates.each do |bucket_date|
          attribute_sets = staging.rows_for(bucket_date).map { |row| ColumnMap.cast(row) }
          key_ids, key_values = resolve_part_keys(attribute_sets)
          now = Time.current

          records = attribute_sets.zip(key_values).map do |attrs, key_value|
            rejected += 1 if key_value.nil?

            attrs.merge(snapshot_id: snapshot.id, part_key_id: key_ids[key_value], created_at: now, updated_at: now)
          end

          records.each_slice(INSERT_BATCH) { |slice| BufferLine.insert_all!(slice) }
          inserted += records.size
        end

        snapshot.update!(row_count: inserted, rejected_count: rejected)
      end

      def activation_message(snapshot)
        "Activated #{snapshot.row_count} buffer weeks (#{snapshot.rejected_count} without a key)"
      end
    end
  end
end
