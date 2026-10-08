require "test_helper"

module Csr
  module Buffer
    class IngestTest < ActiveSupport::TestCase
      test "copies every week into a snapshot and keys each row by CPN|MPN" do
        result = ingest(rows: [
          row,
          row("BUCKET_DATE" => "2026-10-03", "VS_SS" => "-0.25"),
          row("MANUFACTURER_PART" => nil)
        ])

        assert_predicate result, :activated?
        assert_equal 3, result.snapshot.row_count
        assert_equal 1, result.snapshot.rejected_count, "a row with no MPN is kept, unkeyed"

        lines = BufferLine.in_snapshot(result.snapshot).where.not(part_key_id: nil).order(:bucket_date)
        assert_equal [ Date.new(2026, 9, 26), Date.new(2026, 10, 3) ], lines.map(&:bucket_date)
        assert_equal [ 0.5, -0.25 ], lines.map { |line| line.vs_ss.to_f }
        assert_equal "CPN-900|MPN-Z", lines.first.part_key.key_value
        assert_equal "FCS-MPN-Z", lines.first.fpn
        assert_equal 8000, lines.first.safety_stock
      end

      test "skips when the table has not been refilled" do
        previous = ingest(rows: [ row ]).snapshot

        result = ingest(rows: [ row ], watermark: previous.source_modified_at)

        assert_predicate result, :skipped?
        assert_equal previous, result.snapshot
      end

      test "a rejected load leaves no rows behind and the previous snapshot serving" do
        weeks = %w[2026-09-26 2026-10-03 2026-10-10 2026-10-17].map { |date| row("BUCKET_DATE" => date) }
        previous = ingest(rows: weeks).snapshot

        result = ingest(rows: [ row ], watermark: previous.source_modified_at + 1.week)

        assert_predicate result, :failed?
        assert_equal previous, Snapshot.current("buffer")
        assert_equal 0, BufferLine.in_snapshot(result.snapshot).count
      end

      private

      def row(attributes = {})
        {
          "CPN" => "CPN-900", "MANUFACTURER_PART" => "MPN-Z", "FCP_PART" => " FCS-MPN-Z ",
          "FCP_SITE" => "702", "SUPPLIER_NAME" => "702: SANYU TECHNOLOGY H K LTD",
          "CUSTOMER_ID" => "702_ZZZFCS003", "DELIVERY_ADDRESS" => "FLX000242",
          "SAFETY_STOCK_CONSIDER_SPQ" => "8,000", "BUCKET_DATE" => "2026-09-26", "VS_SS" => "0.5"
        }.merge(attributes)
      end

      # Only the read side of the staging table is faked; snapshots, keys and
      # buffer lines go through Postgres.
      def ingest(rows:, watermark: Time.utc(2026, 10, 2), **options)
        staging = FakeStaging.new(rows: rows, watermark: watermark)
        Ingest.new(staging: staging, **options).call
      end

      class FakeStaging
        def initialize(rows:, watermark:)
          @rows = rows
          @watermark = watermark
        end

        attr_reader :watermark

        def table_name = "CSR_BUFFER_READINESS"
        def bucket_dates = @rows.map { |row| row["BUCKET_DATE"] }.uniq.sort
        def rows_for(bucket_date) = @rows.select { |row| row["BUCKET_DATE"] == bucket_date }
      end
    end
  end
end
