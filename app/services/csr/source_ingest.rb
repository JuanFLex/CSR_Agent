module Csr
  # What every source load does the same way: open a snapshot, fill it, and let
  # it become visible only if it passes its guards.
  #
  # The DBA reloads the staging tables with truncate+insert. Reading them live
  # would mean serving an empty portal for the length of every load, so this
  # takes a copy instead: new snapshot, then an atomic flip. Readers always see
  # a complete picture, and last week's picture is still there.
  #
  # A subclass says where the rows come from (`source_type`, `staging`,
  # `load_rows`) and, when its source cannot say whether anything changed,
  # overrides `nothing_new?`.
  class SourceIngest
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
        source_file: staging.table_name, source_modified_at: watermark,
        started_at: Time.current
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
      Result.new(status: :activated, snapshot: snapshot, message: activation_message(snapshot))
    end

    def activation_message(snapshot)
      "Activated #{snapshot.row_count} rows"
    end
  end
end
