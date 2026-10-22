module Csr
  module Buffer
    # Copies the "Balance vs SS (Buffer Stock)" row of every part in
    # CS_tempTrendBufferReadinessProjection into a new snapshot.
    #
    # A buffer row carries CPN and MPN, so it resolves to a CPN|MPN key the
    # same way an order line does, and a part with a buffer but no open order
    # still gets its key.
    class Ingest < WeeklyIngest
      def initialize(staging: Reporting::BufferStaging, **options)
        super
      end

      private

      def source_type = "buffer"
      def column_map = ColumnMap
      def line_model = BufferLine
      def value_attribute = :vs_ss

      # Per key, for the report's first week: its safety stock and allocated
      # on hand, which are per row, so read off one week of each row, and its
      # lowest projected week, as Csr::BufferSummary takes it.
      # ponytail: a key with two rows (14 in WK41) adds them up, the same
      # stock counted per FPN or site. If the twins turn out to be one stock
      # counted twice, take MAX here instead.
      def weekly_positions(snapshot)
        lines = BufferLine.in_snapshot(snapshot).where.not(part_key_id: nil)
        week = lines.minimum(:bucket_date)
        on_first_week = ->(sql) { Arel.sql(BufferLine.sanitize_sql_array([ "#{sql} FILTER (WHERE bucket_date = ?)", week ])) }

        lines.group(:part_key_id).pluck(
          :part_key_id,
          on_first_week.("SUM(safety_stock)"),
          on_first_week.("SUM(allocated_on_hand)"),
          Arel.sql("MIN(vs_ss) FILTER (WHERE safety_stock > 0)")
        ).map do |part_key_id, safety_stock, allocated_on_hand, min_vs_ss|
          { part_key_id:, week:, safety_stock:, allocated_on_hand:, min_vs_ss: }
        end
      end
    end
  end
end
