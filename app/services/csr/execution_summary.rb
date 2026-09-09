module Csr
  # The Execution (OSOR) numbers of SUMMARY: B4 through B7, plus the portfolio
  # roll-up in E6:E8.
  #
  # Everything here is a count or an extreme over the order lines belonging to a
  # set of keys, taken from a single snapshot so the numbers are internally
  # consistent even if a load lands while someone is reading.
  class ExecutionSummary
    def initialize(part_keys, snapshot:)
      @part_keys = part_keys
      @snapshot = snapshot
    end

    def call
      return empty if @snapshot.nil?

      combos_found, open_lines, misses, etd_min, etd_max, open_qty = lines.pick(
        key_count_query,
        Arel.sql("COUNT(*)"),
        Arel.sql("COUNT(*) FILTER (WHERE miss)"),
        Arel.sql("MIN(cdd)"),
        Arel.sql("MAX(cdd)"),
        Arel.sql("COALESCE(SUM(baan_ordered), 0)")
      )

      {
        combos_found: combos_found,          # SUMMARY!E6
        open_lines:   open_lines,            # SUMMARY!B4 / E7
        misses:       misses,                # SUMMARY!B5 / E8
        etd_min:      etd_min,               # SUMMARY!B6
        etd_max:      etd_max,
        open_qty:     open_qty               # SUMMARY!B7
      }
    end

    private

    # Count keys independently so a match with no lines still counts as a combo.
    def key_count_query
      PartKey.from(@part_keys.select(:id), :matched_keys).select(Arel.sql("COUNT(*)")).arel.as("combos_found")
    end

    def lines
      @lines ||= OsorLine.in_snapshot(@snapshot).for_keys(@part_keys.select(:id))
    end

    def empty
      {
        combos_found: 0, open_lines: 0, misses: 0, etd_min: nil, etd_max: nil,
        open_qty: 0
      }
    end
  end
end
