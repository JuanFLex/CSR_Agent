module Csr
  module Osor
    # Copies CSR_OSOR_AMERICAS into a new snapshot.
    #
    # Csr::SourceIngest holds the snapshot lifecycle and the guards; what is
    # OSOR's own is the staging table, the part keys every line resolves to,
    # and the miss flag.
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

      # One round trip per batch instead of one per line. Lines whose MPN is
      # missing get no key: they are counted as rejected rather than dropped
      # quietly, because an order line that vanishes from the portal without a
      # trace is worse than one that is visibly unmatched.
      def resolve_part_keys(attribute_sets)
        key_values = []
        candidates = attribute_sets.filter_map do |attrs|
          key_value = PartKey.build_key(attrs[:cpn], attrs[:mpn])
          key_values << key_value
          next if key_value.nil?

          {
            key_value: key_value,
            cpn: PartKey.normalize(attrs[:cpn]),
            mpn: PartKey.normalize(attrs[:mpn]),
            region: @region
          }
        end.uniq { |c| c[:key_value] }

        return [ {}, key_values ] if candidates.empty?

        # ON CONFLICT DO NOTHING rather than read-then-insert: a scheduled run
        # and a forced one can overlap (Snapshot#activate! is built for that),
        # and both may try to create the same new key. The loser skips it
        # instead of failing its whole load on the unique index. All writes go
        # to Postgres, so there is no other adapter to stay neutral for.
        PartKey.insert_all(candidates, unique_by: %i[region key_value])
        ids = PartKey.where(region: @region, key_value: candidates.map { |c| c[:key_value] })
                     .pluck(:key_value, :id).to_h

        [ ids, key_values ]
      end

      def activation_message(snapshot)
        "Activated #{snapshot.row_count} lines (#{snapshot.rejected_count} without a key)"
      end
    end
  end
end
