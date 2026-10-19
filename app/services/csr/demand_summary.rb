module Csr
  # The Demand numbers of SUMMARY, per key: what the Demand Comparison report
  # says of the part (its Status), how much its demand moved inside lead time,
  # and the workbook's own flag on that movement.
  class DemandSummary
    Position = Struct.new(:status, :lt_variation, :lt_variation_pct, keyword_init: true) do
      # The report's Status without its instruction: "Strong variation - Need
      # confirmation" is "Strong variation".
      def label = status.to_s.split(" - ").first

      def steady? = label.to_s.start_with?("Steady")

      # SUMMARY!B34. It reads the signed ratio, so a drop is never flagged,
      # however deep — which is why the report's Status is shown beside it.
      def flag
        pct = lt_variation_pct.to_d
        return :red if pct >= BigDecimal("0.25")
        pct >= BigDecimal("0.15") ? :yellow : :green
      end
    end

    def initialize(part_keys, snapshot:)
      @part_keys = part_keys
      @snapshot = snapshot
    end

    # => { part_key_id => Position }, for the keys the demand report carries.
    def call
      return {} if @snapshot.nil?

      # ponytail: a key with two rows (two FPNs, two ship-tos) shows the worse
      # one: not steady first, then the widest movement either way. If Alex
      # wants them added up instead, sum the pieces here.
      lines.select("DISTINCT ON (part_key_id) part_key_id, status, lt_variation, lt_variation_pct")
           .order(Arel.sql("part_key_id, (status LIKE 'Steady%'), ABS(lt_variation_pct) DESC NULLS LAST"))
           .to_h do |line|
        [ line.part_key_id, Position.new(status: line.status, lt_variation: line.lt_variation, lt_variation_pct: line.lt_variation_pct) ]
      end
    end

    private

    def lines
      DemandLine.in_snapshot(@snapshot).for_keys(@part_keys.select(:id))
    end
  end
end
