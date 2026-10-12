module Csr
  # The Commit numbers of SUMMARY, per key: the worst the commit balance gets
  # (Commit_MinBalance) and the first week it is short
  # (Commit_FirstShortageDate).
  #
  # Both are extremes over every commit row of the key, as the workbook's
  # List.Min is. A key can carry more than one row (two customers, two
  # ship-tos); those stay context on the rows and never split the key.
  #
  # One deliberate difference from the workbook: the first week is the
  # earliest date. The workbook takes the minimum of the week labels as text
  # ("MM-DD-YY"), which puts January before October; on the week 41 file that
  # is the wrong week for 148 of the 391 parts that run short.
  class CommitSummary
    Position = Struct.new(:min_balance, :short_from, keyword_init: true) do
      # The build book's "Commit < 0". The balance is never positive.
      def short? = min_balance.to_d.negative?
    end

    def initialize(part_keys, snapshot:)
      @part_keys = part_keys
      @snapshot = snapshot
    end

    # => { part_key_id => Position }, for the keys the commit report carries.
    def call
      return {} if @snapshot.nil?

      lines.group(:part_key_id).pluck(
        :part_key_id,
        Arel.sql("MIN(balance)"),
        Arel.sql("MIN(bucket_date) FILTER (WHERE balance < 0)")
      ).to_h do |part_key_id, min_balance, short_from|
        [ part_key_id, Position.new(min_balance: min_balance, short_from: short_from) ]
      end
    end

    private

    def lines
      CommitLine.in_snapshot(@snapshot).for_keys(@part_keys.select(:id))
    end
  end
end
