module Csr
  # What the Buffer Readiness, Commit and Demand Variation pages show of the
  # searched keys: each row the report carries for a key, week by week, and
  # where the key stood in earlier weeks. The *Summary services answer "where
  # does the key stand"; this is the detail behind that answer.
  #
  # A key can carry more than one row of a report (two FPNs, sites or
  # ship-tos). Rows are listed one by one; a chart adds them up, as stock or
  # demand on the same part.
  class WeeklyDetail
    BufferRow = Struct.new(:fpn, :site, :supplier, :customer_id, :ship_address,
                           :safety_stock, :allocated_on_hand, :min_vs_ss, :at_target_from, keyword_init: true) do
      def no_target? = !safety_stock.to_d.positive?

      # The report's "Buffer % Coverage": the allocated stock as a multiple of
      # the safety stock.
      def coverage = (allocated_on_hand.to_d / safety_stock unless no_target?)
    end

    CommitRow = Struct.new(:fpn, :customer_id, :ship_address, :min_balance, :short_from, keyword_init: true)

    def initialize(part_keys, sources)
      @part_keys = part_keys
      @sources = sources
    end

    # => { part_key_id => [ BufferRow ] }
    def buffer_rows
      @buffer_rows ||= lines(BufferLine, "buffer")
        .group(:part_key_id, :fpn, :site, :supplier, :customer_id, :ship_address)
        .order(:part_key_id, :fpn, :site, :supplier)
        .pluck(:part_key_id, :fpn, :site, :supplier, :customer_id, :ship_address,
               Arel.sql("MAX(safety_stock)"), Arel.sql("MAX(allocated_on_hand)"),
               Arel.sql("MIN(vs_ss)"), Arel.sql("MIN(bucket_date) FILTER (WHERE vs_ss >= 1)"))
        .group_by(&:first).transform_values do |rows|
          rows.map { |_id, *values| BufferRow.new(**BufferRow.members.zip(values).to_h) }
        end
    end

    # => { part_key_id => [ CommitRow ] }
    def commit_rows
      @commit_rows ||= lines(CommitLine, "commit")
        .group(:part_key_id, :fpn, :customer_id, :ship_address)
        .order(:part_key_id, :fpn, :customer_id)
        .pluck(:part_key_id, :fpn, :customer_id, :ship_address,
               Arel.sql("MIN(balance)"), Arel.sql("MIN(bucket_date) FILTER (WHERE balance < 0)"))
        .group_by(&:first).transform_values do |rows|
          rows.map { |_id, *values| CommitRow.new(**CommitRow.members.zip(values).to_h) }
        end
    end

    # => { part_key_id => [ DemandLine ] }
    def demand_rows
      @demand_rows ||= lines(DemandLine, "demand").order(:fpn, :ship_address).group_by(&:part_key_id)
    end

    # => { part_key_id => [ [ week, balance in pieces, safety stock ] ] }, over
    # the rows with a safety stock: vs_ss is the balance as a multiple of it,
    # so it gives the pieces back. A key with no target has nothing to draw.
    def buffer_weeks
      lines(BufferLine, "buffer").where("safety_stock > 0").group(:part_key_id, :bucket_date).order(:bucket_date)
        .pluck(:part_key_id, :bucket_date, Arel.sql("SUM(vs_ss * safety_stock)"), Arel.sql("SUM(safety_stock)"))
        .group_by(&:first).transform_values { |rows| rows.map { |_id, *week| week } }
    end

    # => { part_key_id => [ [ week, balance ] ] }
    def commit_weeks
      lines(CommitLine, "commit").group(:part_key_id, :bucket_date).order(:bucket_date)
        .pluck(:part_key_id, :bucket_date, Arel.sql("SUM(balance)"))
        .group_by(&:first).transform_values { |rows| rows.map { |_id, *week| week } }
    end

    # => { part_key_id => [ weeks, last week's demand, this week's ] }, for the
    # keys whose rows carry the report's two snapshots.
    def demand_weeks
      demand_rows.transform_values { |rows|
        rows = rows.select(&:old_weeks)
        next if rows.empty?

        size = rows.map { |row| row.old_weeks.size }.max
        add_up = ->(attribute) { Array.new(size) { |i| rows.sum { |row| row.public_send(attribute)[i].to_d } } }
        [ Array.new(size) { |i| rows.first.old_snapshot_on + 7 * i }, add_up.(:old_weeks), add_up.(:new_weeks) ]
      }.compact
    end

    # => { part_key_id => [ WeeklyPosition ] }, oldest week first.
    def history
      @history ||= WeeklyPosition.for_keys(@part_keys.select(:id)).order(:week).group_by(&:part_key_id)
    end

    private

    def lines(model, source)
      snapshot = @sources[source]
      snapshot ? model.in_snapshot(snapshot).for_keys(@part_keys.select(:id)) : model.none
    end
  end
end
