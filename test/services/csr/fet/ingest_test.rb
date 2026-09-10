require "test_helper"

module Csr
  module Fet
    class IngestTest < ActiveSupport::TestCase
      test "copies the open escalations into a snapshot and normalizes the part handles" do
        result = ingest(rows: [ row, row("ESCALATION_NUMBER" => "20250716610058.3", "MFG_PARTNO" => " KSC721JLFS ") ])

        assert_predicate result, :activated?
        assert_predicate result.snapshot, :active?
        assert_equal 2, result.snapshot.row_count

        escalation = Escalation.in_snapshot(result.snapshot).order(:escalation_number).first
        assert_equal "KSC721JLFS", escalation.mpn
        assert_equal "FCS-KSC721JLFS", escalation.fpn
        assert_equal "OPEN", escalation.escalation_status
        assert_equal 67, escalation.days_open
        assert_nil escalation.impact_date, "the 1969 epoch sentinel is not a date"
      end

      test "reloads when the open row count moved even though the watermark did not" do
        previous = ingest(rows: [ row ]).snapshot

        result = ingest(rows: [ row, row("ESCALATION_NUMBER" => "X-2") ],
                        watermark: previous.source_modified_at)

        assert_predicate result, :activated?
        assert_predicate previous.reload, :superseded?
      end

      test "skips when neither the watermark nor the open row count moved" do
        previous = ingest(rows: [ row ]).snapshot

        result = ingest(rows: [ row ], watermark: previous.source_modified_at)

        assert_predicate result, :skipped?
        assert_equal previous, result.snapshot
      end

      test "keeps the previous snapshot serving when the load comes back empty" do
        previous = ingest(rows: [ row ]).snapshot

        result = ingest(rows: [], watermark: previous.source_modified_at + 1.day)

        assert_predicate result, :failed?
        assert_equal previous, Snapshot.current("escalation")
      end

      private

      def row(attributes = {})
        {
          "COMP_ID" => "702", "FACILITY" => "CENTRAL PROCUREMENT USA 702",
          "REGION_CODE" => "AMERICAS", "ESCALATION_NUMBER" => "20250716610058.2",
          "ESCALATION_STATUS" => "OPEN", "ESCALATION_TYPE" => "SHORTAGE ESCALATION",
          "ITEM" => "FCS-KSC721JLFS", "MFG_PARTNO" => "KSC721JLFS",
          "DAYS_OPEN" => 67, "SHORTAGE_QTY" => "1,500",
          "IMPACT_DATE" => Time.utc(1969, 12, 31),
          "UPDATED_DATE" => Time.utc(2026, 9, 10),
          "CURRENT_OWNER_NAME" => "Aswin Kumar M"
        }.merge(attributes)
      end

      # Only the read side of the staging table is faked; snapshots and
      # escalations go through Postgres.
      def ingest(rows:, watermark: Time.utc(2026, 9, 10), **options)
        staging = FakeStaging.new(rows: rows, watermark: watermark)
        Ingest.new(staging: staging, **options).call
      end

      class FakeStaging
        def initialize(rows:, watermark:)
          @rows = rows
          @watermark = watermark
        end

        attr_reader :watermark

        def table_name = "CSR_FET"
        def open_escalations = self
        def select(_columns) = self
        def to_sql = "SELECT * FROM CSR_FET"
        def count = @rows.size
        def connection = self
        def select_all(_sql) = @rows
      end
    end
  end
end
