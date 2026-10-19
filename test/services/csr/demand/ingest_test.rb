require "test_helper"

module Csr
  module Demand
    # The guards every load shares (empty, shrunk, unchanged) are
    # SourceIngest's and covered with OSOR's. This is only what is Demand's
    # own: the columns read by name.
    class IngestTest < ActiveSupport::TestCase
      FakeStaging = Struct.new(:rows, keyword_init: true) do
        def table_name = "CSR_DemandComparison"
        def watermark = Time.utc(2026, 10, 12)
        def count = rows.size
      end

      test "reads the report's columns by name and rejects a row without a key" do
        row = {
          "CPN" => " CPN-900 ", "MANUFACTURER_PART" => "MPN-Z", "FCP_PART" => "FCS-MPN-Z",
          "CUSTOMER_NAME" => "ZZZCAR018", "DELIVERY_ADDRESS" => "FLX000558", "COMPANY" => "702",
          "EFF_LEAD_TIME" => "21", "VARIATION_INSIDE_LT" => "3,000", "VARIATION_INSIDE_LT_PCT" => 0.3,
          "TOTAL_VARIATION" => 4500, "TOTAL_VARIATION_PCT" => 0.12, "STATUS" => "Strong variation - Need confirmation"
        }
        orphan = row.merge("CPN" => nil)

        result = Ingest.new(staging: FakeStaging.new(rows: [ row, orphan ])).call

        assert_predicate result, :activated?
        assert_equal 1, result.snapshot.rejected_count
        lines = DemandLine.in_snapshot(result.snapshot).order(:id).to_a
        assert_equal 2, lines.size
        line = lines.first
        assert_equal "CPN-900|MPN-Z", line.part_key.key_value
        assert_equal [ "Strong variation - Need confirmation", 3000, BigDecimal("0.3") ], [ line.status, line.lt_variation, line.lt_variation_pct ]
      end
    end
  end
end
