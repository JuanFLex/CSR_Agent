module Csr
  # What every source load does the same way: open a snapshot, fill it, and let
  # it become visible only if it passes its guards.
  #
  # The DBA reloads the staging tables with truncate+insert. Reading them live
  # would mean serving an empty portal for the length of every load, so this
  # takes a copy instead: new snapshot, then an atomic flip. Readers always see
  # a complete picture, and the previous one is still there to roll back to.
  #
  # A subclass says where the rows come from (`source_type`, `staging`,
  # `load_rows`) and, when its source cannot say whether anything changed,
  # overrides `nothing_new?`.
  class SourceIngest
    # A load that arrives more than this much smaller than the last good one
    # is treated as a truncated or partial export rather than as news.
    SHRINK_TOLERANCE = 0.30

    INSERT_BATCH = 1_000

    Result = Struct.new(:status, :snapshot, :message, keyword_init: true) do
      def activated? = status == :activated
      def skipped?   = status == :skipped
      def failed?    = status == :failed
    end

    def initialize(region: DEFAULT_REGION, force: false)
      @region = region
      @force = force
    end

    def call
      watermark = staging.watermark
      previous = Snapshot.current(source_type, region: @region)

      if !@force && nothing_new?(previous, watermark)
        return Result.new(status: :skipped, snapshot: previous,
                          message: "#{staging.table_name} unchanged since #{watermark.iso8601}")
      end

      snapshot = Snapshot.create!(
        region: @region, source_type: source_type, status: :loading,
        source_file: staging.table_name, source_modified_at: watermark
      )

      load_rows(snapshot)
      guard_and_activate(snapshot, previous)
    rescue StandardError => e
      snapshot&.fail!("#{e.class}: #{e.message}")
      Result.new(status: :failed, snapshot: snapshot, message: e.message)
    end

    private

    # True when the staging table cannot have anything the last snapshot missed.
    def nothing_new?(previous, watermark)
      previous && watermark && previous.source_modified_at &&
        watermark <= previous.source_modified_at
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
        if shrink > SHRINK_TOLERANCE
          reason = format(
            "Row count fell %.1f%% (%d -> %d), beyond the %.0f%% tolerance; kept previous snapshot active",
            shrink * 100, previous.row_count, snapshot.row_count, SHRINK_TOLERANCE * 100
          )
          snapshot.fail!(reason)
          return Result.new(status: :failed, snapshot: snapshot, message: reason)
        end
      end

      snapshot.activate!
      record_history(snapshot)
      prune_history
      Result.new(status: :activated, snapshot: snapshot, message: activation_message(snapshot))
    end

    # The CPN|MPN key of each row, created if this is the first time the part
    # is seen: one round trip per batch instead of one per row. Returns the ids
    # by key value, and the key value of every row in order. A row whose CPN
    # or MPN is missing gets no key; the caller counts it as rejected rather
    # than dropping it quietly, because a row that vanishes from the portal
    # without a trace is worse than one that is visibly unmatched.
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

    # The week this load describes, kept in Csr::WeeklyPosition after the
    # snapshot itself is pruned. Only weekly sources keep one. Like pruning, a
    # failure must not fail a snapshot already serving; a forced reload of the
    # same week writes it again.
    def record_history(snapshot)
      positions = weekly_positions(snapshot)
      WeeklyPosition.record!(positions, positions.first.keys - %i[part_key_id week]) if positions.present?
    rescue StandardError => e
      Rails.logger.error("[csr.#{source_type}] recording the week's positions failed: #{e.message}")
    end

    # => [ { part_key_id:, week:, <the source's columns> } ]
    def weekly_positions(_snapshot) = []

    # Housekeeping, not part of the load: a failure here must not turn a
    # snapshot that is already serving into a failed one, so it is logged and
    # the next activation tries again.
    def prune_history
      Snapshot.prune!(source_type, region: @region)
    rescue StandardError => e
      Rails.logger.error("[csr.#{source_type}] pruning old snapshots failed: #{e.message}")
    end

    def activation_message(snapshot)
      "Activated #{snapshot.row_count} rows"
    end
  end
end
