module Csr
  module Demand
    # Copies one row per part of CSR_DemandComparison into a new snapshot.
    class Ingest < SourceIngest
      include WaitsForEtl

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

          records = attribute_sets.zip(key_values, rows).map do |attrs, key_value, row|
            rejected += 1 if key_value.nil?
            attrs.merge(weeks(row), snapshot_id: snapshot.id, part_key_id: key_ids[key_value], created_at: now, updated_at: now)
          end

          DemandLine.insert_all!(records)
          inserted += records.size
        end

        snapshot.update!(row_count: inserted, rejected_count: rejected)

        # A table refilled while it was being read gives a mix of two loads.
        raise "#{staging.table_name} changed while it was being read" unless staging.count == count
      end

      # The two snapshots Reporting::DemandStaging pairs with the Sales row.
      def weeks(row)
        {
          old_snapshot_on: row["OLD_SNAPSHOT_ON"], new_snapshot_on: row["NEW_SNAPSHOT_ON"],
          old_weeks: row["OLD_WEEKS"]&.map { |value| ColumnMap.coerce(value, :decimal) },
          new_weeks: row["NEW_WEEKS"]&.map { |value| ColumnMap.coerce(value, :decimal) }
        }
      end

      # Per key, for this week's snapshot: the demand over the whole horizon
      # and how much of it moved inside lead time. A key with two rows (two
      # FPNs or ship-tos) adds them up; both are demand on the part.
      def weekly_positions(snapshot)
        DemandLine.in_snapshot(snapshot).where.not(part_key_id: nil).where.not(new_snapshot_on: nil)
                  .pluck(:part_key_id, :new_snapshot_on, :new_weeks, :lt_variation)
                  .group_by { |part_key_id, week, _weeks, _lt| [ part_key_id, week ] }
                  .map do |(part_key_id, week), rows|
          { part_key_id:, week:,
            demand_total: rows.sum { |_id, _week, new_weeks, _lt| new_weeks.to_a.compact.sum },
            lt_variation: rows.sum { |_id, _week, _weeks, lt_variation| lt_variation.to_d } }
        end
      end

      def activation_message(snapshot)
        "Activated #{snapshot.row_count} demand rows (#{snapshot.rejected_count} without a key)"
      end
    end
  end
end
