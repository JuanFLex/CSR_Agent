require "test_helper"

module Csr
  module Commit
    # What a weekly ingest does in general is covered by Buffer::IngestTest.
    # This is only what is Commit's own: the sheet's unnamed columns.
    class IngestTest < ActiveSupport::TestCase
      FIRST_WEEK = Date.new(2026, 10, 3)

      FakeStaging = Struct.new(:rows, keyword_init: true) do
        def table_name = "CSR_CustomerCommitment"
        def watermark = Time.utc(2026, 10, 12)
        def age = 2.days
        def layout_ok? = true
        def count = 8
      end

      FakeCalendar = Struct.new(:first_week, :end_customers) do
        def table_name = "CS_tempVerticalCommit"
      end

      test "reads the sheet's unnamed columns and stores its 52 weeks" do
        row = {
          "F3" => "702_ZZZCAR018", "F4" => "FLX000558", "F5" => "CPN-900",
          "F6" => " FCS-MPN-Z ", "F7" => "MPN-Z", "F18" => 0.0, "F19" => -4000.0, "F69" => -12.0
        }

        result = Ingest.new(staging: FakeStaging.new(rows: [ row ]), calendar: FakeCalendar.new(FIRST_WEEK, {})).call

        assert_predicate result, :activated?
        lines = CommitLine.in_snapshot(result.snapshot).order(:bucket_date).to_a
        assert_equal 52, lines.size
        assert_equal "CPN-900|MPN-Z", lines.first.part_key.key_value
        assert_equal [ "FCS-MPN-Z", "702_ZZZCAR018", "FLX000558" ], lines.first.values_at(:fpn, :customer_id, :ship_address)
        assert_equal [ 0, -4000 ], lines.first(2).map(&:balance)
        assert_equal [ FIRST_WEEK + 51 * 7, -12 ], [ lines.last.bucket_date, lines.last.balance ]
      end

      test "gives the keys their end customer from the vertical sheet" do
        row = { "F5" => "CPN-900", "F7" => "MPN-Z", "F18" => 0.0 }
        calendar = FakeCalendar.new(FIRST_WEEK, { "CPN-900" => "PHILO" })

        result = Ingest.new(staging: FakeStaging.new(rows: [ row ]), calendar: calendar).call

        assert_predicate result, :activated?
        assert_equal "PHILO", PartKey.find_by!(key_value: "CPN-900|MPN-Z").end_customer
      end

      test "a vertical sheet that cannot give the customers does not fail the load" do
        calendar = FakeCalendar.new(FIRST_WEEK)
        def calendar.end_customers = raise("connection reset")

        result = Ingest.new(staging: FakeStaging.new(rows: [ { "F5" => "CPN-900", "F7" => "MPN-Z" } ]), calendar: calendar).call

        assert_predicate result, :activated?
      end
    end
  end
end
