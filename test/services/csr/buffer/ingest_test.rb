require "test_helper"

module Csr
  module Buffer
    class IngestTest < ActiveSupport::TestCase
      FIRST_WEEK = Date.new(2026, 10, 3)

      test "turns the week columns of each row into dated lines, keyed by CPN|MPN" do
        result = ingest(rows: [ row("F21" => "0.5", "F22" => "-0.25", "FUTURE" => "3"), row("MANUFACTURER_PART" => nil) ])

        assert_predicate result, :activated?
        assert_equal 102, result.snapshot.row_count
        assert_equal 51, result.snapshot.rejected_count, "a row with no MPN is kept, unkeyed"

        lines = BufferLine.in_snapshot(result.snapshot).where.not(part_key_id: nil).order(:bucket_date).to_a
        assert_equal [ FIRST_WEEK, FIRST_WEEK + 7 ], lines.first(2).map(&:bucket_date)
        assert_equal [ 0.5, -0.25 ], lines.first(2).map { |line| line.vs_ss.to_f }
        assert_equal [ FIRST_WEEK + 50 * 7, 3 ], [ lines.last.bucket_date, lines.last.vs_ss ], "FUTURE is the 51st week"
        assert_equal "CPN-900|MPN-Z", lines.first.part_key.key_value
        assert_equal "FCS-MPN-Z", lines.first.fpn
        assert_equal 8000, lines.first.safety_stock
      end

      test "keeps the allocated on hand, and the week's position in the history" do
        result = ingest(rows: [ row("F21" => "2", "F22" => "0.5", "ALLOCATED_CUSTOMER_ON_HAND" => "16,000"),
                                row("FCP_SITE" => "703", "F21" => "0.25", "SAFETY_STOCK_CONSIDER_SPQ" => "0") ])

        assert_equal [ 16_000 ], BufferLine.in_snapshot(result.snapshot).where(site: "702").distinct.pluck(:allocated_on_hand)
        position = WeeklyPosition.sole
        assert_equal [ FIRST_WEEK, 8000, 16_000, 0.5 ], [ position.week, position.safety_stock, position.allocated_on_hand, position.min_vs_ss ]

        WeeklyPosition.record!([ { part_key_id: position.part_key_id, week: FIRST_WEEK, demand_total: 900 } ], %i[demand_total])
        assert_equal [ 8000, 900 ], [ position.reload.safety_stock, position.demand_total ], "each source writes only its own columns"
      end

      test "skips when the table has not been refilled" do
        previous = ingest(rows: [ row ]).snapshot

        result = ingest(rows: [ row ], watermark: previous.source_modified_at)

        assert_predicate result, :skipped?
        assert_equal previous, result.snapshot
      end

      test "a rejected load leaves no rows behind and the previous snapshot serving" do
        previous = ingest(rows: [ row, row, row, row ]).snapshot

        result = ingest(rows: [ row ], watermark: previous.source_modified_at + 1.week)

        assert_predicate result, :failed?
        assert_equal previous, Snapshot.current("buffer")
        assert_equal 0, BufferLine.in_snapshot(result.snapshot).count
      end

      test "leaves a load that may still be running for the next poll" do
        result = ingest(rows: [ row ], age: 10.minutes)

        assert_predicate result, :skipped?
        assert_nil Snapshot.current("buffer")
        assert_predicate ingest(rows: [ row ], age: 10.minutes, force: true), :activated?
      end

      test "rejects a first week that is not a Saturday" do
        result = ingest(rows: [ row ], first_week: FIRST_WEEK + 1)

        assert_predicate result, :failed?
        assert_match(/not a Saturday/, result.message)
      end

      test "rejects a table whose header row no longer matches the map" do
        result = ingest(rows: [ row ], layout_ok: false)

        assert_predicate result, :failed?
        assert_match(/columns/, result.message)
      end

      test "rejects a table that was refilled while it was being read" do
        result = ingest(rows: [ row ], counts: [ 8, 16 ])

        assert_predicate result, :failed?
        assert_equal 0, BufferLine.in_snapshot(result.snapshot).count
      end

      private

      def row(attributes = {})
        {
          "CPN" => "CPN-900", "MANUFACTURER_PART" => "MPN-Z", "FCP_PART" => " FCS-MPN-Z ",
          "FCP_SITE" => "702", "SUPPLIER_NAME" => "702: SANYU TECHNOLOGY H K LTD",
          "CUSTOMER_ID" => "702_ZZZFCS003", "DELIVERY_ADDRESS" => "FLX000242",
          "SAFETY_STOCK_CONSIDER_SPQ" => "8,000", "ALLOCATED_CUSTOMER_ON_HAND" => "0"
        }.merge(attributes)
      end

      # Only the read side of the staging tables is faked; snapshots, keys and
      # buffer lines go through Postgres.
      def ingest(rows:, watermark: Time.utc(2026, 10, 9), age: 2.days, layout_ok: true, counts: [ 8 ],
                 first_week: FIRST_WEEK, **options)
        staging = FakeStaging.new(rows: rows, watermark: watermark, age: age, layout_ok?: layout_ok, counts: counts.dup)
        Ingest.new(staging: staging, calendar: FakeCalendar.new(first_week: first_week), **options).call
      end

      FakeStaging = Struct.new(:rows, :watermark, :age, :layout_ok?, :counts, keyword_init: true) do
        def table_name = "CS_tempTrendBufferReadinessProjection"
        def count = counts.one? ? counts.first : counts.shift
      end

      FakeCalendar = Struct.new(:first_week, keyword_init: true) do
        def table_name = "CS_tempVerticalCommit"
      end
    end
  end
end
