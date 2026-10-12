module Csr
  module Osor
    # Copies CSR_OSOR_AMERICAS into a new snapshot.
    #
    # Csr::SourceIngest holds the snapshot lifecycle and the guards; what is
    # OSOR's own is the staging table and the miss flag.
    class Ingest < SourceIngest
      def initialize(region: DEFAULT_REGION, **options)
        super
        @staging = Reporting::OsorStaging.for_region(region)
      end

      private

      attr_reader :staging

      def source_type = "osor"

      def load_rows(snapshot)
        # select_all rather than instantiating 11k read-only records: the
        # ColumnMap works on raw rows anyway.
        rows = staging.connection.select_all(staging.all.to_sql).to_a
        rejected = 0
        inserted = 0

        rows.each_slice(INSERT_BATCH) do |slice|
          attribute_sets = slice.map { |row| ColumnMap.cast(row) }
          key_ids, key_values = resolve_part_keys(attribute_sets)
          now = Time.current

          records = attribute_sets.zip(key_values).map do |attrs, key_value|
            rejected += 1 if key_value.nil?

            attrs.merge(
              snapshot_id: snapshot.id,
              part_key_id: key_ids[key_value],
              miss: OsorLine.miss?(attrs[:pdd], attrs[:cdd]),
              created_at: now,
              updated_at: now
            )
          end

          OsorLine.insert_all!(records) if records.any?
          inserted += records.size
        end

        snapshot.update!(row_count: inserted, rejected_count: rejected)
      end

      def activation_message(snapshot)
        "Activated #{snapshot.row_count} lines (#{snapshot.rejected_count} without a key)"
      end
    end
  end
end
