module Csr
  # The Buffer numbers of SUMMARY (B19:B20), per key: the lowest the projected
  # buffer gets against its safety stock, and the first week it is at target.
  #
  # Both are extremes over every buffer row of the key, as the workbook's
  # List.Min is. A key can carry more than one row (FCS- and FCS1- twins, two
  # suppliers); those stay context on the rows and never split the key.
  #
  # One deliberate difference from the workbook: rows with no safety stock are
  # left out. The report writes 0 in every week of such a row, the workbook
  # reads that as "0 x safety stock", and its "RED if Buffer < 1" then fires
  # on the 89% of keys that never had a buffer target (4,188 of 4,709
  # measured). Here those keys are `no_target?`. The workbook's own patch for
  # this, blanking the date when the minimum is exactly 0, is not needed and
  # would hide the date of a key whose balance merely touches zero.
  class BufferSummary
    Position = Struct.new(:min_vs_ss, :at_target_from, keyword_init: true) do
      # No row of the key carries a safety stock, so there is nothing to be below.
      def no_target? = min_vs_ss.nil?

      # The build book's "Buffer Gap": Buffer_MinVsSS < 1.
      def below_target? = !no_target? && min_vs_ss < 1
    end

    def initialize(part_keys, snapshot:)
      @part_keys = part_keys
      @snapshot = snapshot
    end

    # => { part_key_id => Position }, for the keys the buffer report carries.
    #
    # `at_target_from` is the workbook's Buffer_FirstRecoveryDate: the first
    # week at or above 1, whether or not a week below 1 comes before it. For a
    # part that starts covered and dips later it is simply the first week.
    def call
      return {} if @snapshot.nil?

      lines.group(:part_key_id).pluck(
        :part_key_id,
        Arel.sql("MIN(vs_ss) FILTER (WHERE safety_stock > 0)"),
        Arel.sql("MIN(bucket_date) FILTER (WHERE safety_stock > 0 AND vs_ss >= 1)")
      ).to_h do |part_key_id, min_vs_ss, at_target_from|
        [ part_key_id, Position.new(min_vs_ss: min_vs_ss, at_target_from: at_target_from) ]
      end
    end

    private

    def lines
      BufferLine.in_snapshot(@snapshot).for_keys(@part_keys.select(:id))
    end
  end
end
