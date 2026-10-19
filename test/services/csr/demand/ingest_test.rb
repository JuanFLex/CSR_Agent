require "test_helper"

module Csr
  module Demand
    # The guards every load shares (empty, shrunk, unchanged) are
    # SourceIngest's and covered with OSOR's. This is only what is Demand's
    # own: the columns read by name, the wait for the ETL and the read that
    # must not mix two loads.
    class IngestTest < ActiveSupport::TestCase
      test "reads the report's columns by name and rejects a row without a key" do
        result = ingest(rows: [ row, row("CPN" => nil) ])

        assert_predicate result, :activated?
        assert_equal 1, result.snapshot.rejected_count
        lines = DemandLine.in_snapshot(result.snapshot).order(:id).to_a
        assert_equal 2, lines.size
        line = lines.first
        assert_equal "CPN-900|MPN-Z", line.part_key.key_value
        assert_equal [ "Strong variation - Need confirmation", 3000, BigDecimal("0.3") ], [ line.status, line.lt_variation, line.lt_variation_pct ]
      end

      test "leaves a load that may still be running for the next poll" do
        result = ingest(rows: [ row ], age: 10.minutes)

        assert_predicate result, :skipped?
        assert_nil Snapshot.current("demand")
        assert_predicate ingest(rows: [ row ], age: 10.minutes, force: true), :activated?
      end

      test "rejects a table that was refilled while it was being read" do
        result = ingest(rows: [ row ], counts: [ 1, 2 ])

        assert_predicate result, :failed?
        assert_nil Snapshot.current("demand")
        assert_equal 0, DemandLine.in_snapshot(result.snapshot).count
      end

      private

      def row(attributes = {})
        {
          "CPN" => " CPN-900 ", "MANUFACTURER_PART" => "MPN-Z", "FCP_PART" => "FCS-MPN-Z",
          "CUSTOMER_NAME" => "ZZZCAR018", "DELIVERY_ADDRESS" => "FLX000558", "COMPANY" => "702",
          "EFF_LEAD_TIME" => "21", "VARIATION_INSIDE_LT" => "3,000", "VARIATION_INSIDE_LT_PCT" => 0.3,
          "TOTAL_VARIATION" => 4500, "TOTAL_VARIATION_PCT" => 0.12, "STATUS" => "Strong variation - Need confirmation"
        }.merge(attributes)
      end

      # Only the read side of the staging table is faked; snapshots, keys and
      # demand lines go through Postgres.
      def ingest(rows:, age: 2.days, counts: [ rows.size ], **options)
        Ingest.new(staging: FakeStaging.new(rows: rows, age: age, counts: counts.dup), **options).call
      end

      FakeStaging = Struct.new(:rows, :age, :counts, keyword_init: true) do
        def table_name = "CSR_DemandComparison"
        def watermark = Time.utc(2026, 10, 12)
        def count = counts.one? ? counts.first : counts.shift
      end
    end
  end
end
