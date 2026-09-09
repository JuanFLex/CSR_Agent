module Csr
  module Osor
    # Copies CSR_OSOR_AMERICAS into a new snapshot and activates it only if the
    # load looks sane.
    #
    # The DBA reloads that staging table with truncate+insert. Reading it live
    # would mean serving an empty portal for the length of every load, so this
    # service takes a copy instead: new snapshot, then an atomic flip. Readers
    # always see a complete picture, and last week's picture is still there.
    class Ingest
      # A load that arrives more than this much smaller than the last good one
      # is treated as a truncated or partial export rather than as news.
      DEFAULT_SHRINK_TOLERANCE = 0.30

      INSERT_BATCH = 1_000

      Result = Struct.new(:status, :snapshot, :message, keyword_init: true) do
        def activated? = status == :activated
        def skipped?   = status == :skipped
        def failed?    = status == :failed
      end

      def initialize(region: DEFAULT_REGION, force: false, shrink_tolerance: DEFAULT_SHRINK_TOLERANCE)
        @region = region
        @force = force
        @shrink_tolerance = shrink_tolerance
        @staging = Reporting::OsorStaging.for_region(region)
      end

      def call
        watermark = @staging.watermark
        previous = Snapshot.current("osor", region: @region)

        # Nothing new since the last load. This is the common case when polling.
        if !@force && previous && watermark && previous.source_modified_at &&
           watermark <= previous.source_modified_at
          return Result.new(status: :skipped, snapshot: previous,
                            message: "#{@staging.table_name} unchanged since #{watermark.iso8601}")
        end

        snapshot = Snapshot.create!(
          region: @region, source_type: "osor", status: :loading,
          source_file: @staging.table_name, source_modified_at: watermark,
          started_at: Time.current
        )

        load_rows(snapshot)
        guard_and_activate(snapshot, previous)
      rescue StandardError => e
        snapshot&.fail!("#{e.class}: #{e.message}")
        Result.new(status: :failed, snapshot: snapshot, message: e.message)
      end

      private

      def load_rows(snapshot)
        # select_all rather than instantiating 11k read-only records: the
        # ColumnMap works on raw rows anyway.
        rows = @staging.connection.select_all(@staging.all.to_sql).to_a
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

        candidate_values = candidates.map { |c| c[:key_value] }
        existing = PartKey.where(region: @region, key_value: candidate_values).pluck(:key_value, :id).to_h

        # Insert only what is genuinely new, rather than leaning on upsert. The
        # ingest is single-threaded and scheduled, so the read-then-insert is
        # safe here, and it keeps the code free of adapter-specific MERGE/ON
        # CONFLICT behaviour.
        fresh = candidates.reject { |c| existing.key?(c[:key_value]) }

        if fresh.any?
          now = Time.current
          PartKey.insert_all!(fresh.map { |c| c.merge(created_at: now, updated_at: now) })
          existing.merge!(
            PartKey.where(region: @region, key_value: fresh.map { |c| c[:key_value] })
                   .pluck(:key_value, :id).to_h
          )
        end

        [ existing, key_values ]
      end

      # The difference between "live" and "sometimes blank": a snapshot only
      # becomes visible if it carries data and is not dramatically smaller than
      # the last good one. Otherwise it is parked and the previous one keeps
      # serving.
      def guard_and_activate(snapshot, previous)
        if snapshot.row_count.zero?
          snapshot.fail!("Staging table returned 0 rows; kept previous snapshot active")
          return Result.new(status: :failed, snapshot: snapshot, message: "0 rows")
        end

        if previous&.row_count&.positive?
          shrink = 1.0 - (snapshot.row_count.to_f / previous.row_count)
          if shrink > @shrink_tolerance
            reason = format(
              "Row count fell %.1f%% (%d -> %d), beyond the %.0f%% tolerance; kept previous snapshot active",
              shrink * 100, previous.row_count, snapshot.row_count, @shrink_tolerance * 100
            )
            snapshot.fail!(reason)
            return Result.new(status: :failed, snapshot: snapshot, message: reason)
          end
        end

        snapshot.activate!
        Result.new(status: :activated, snapshot: snapshot,
                   message: "Activated #{snapshot.row_count} lines (#{snapshot.rejected_count} without a key)")
      end
    end
  end
end
