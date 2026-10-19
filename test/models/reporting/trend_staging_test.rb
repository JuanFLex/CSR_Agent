require "test_helper"

module Reporting
  # The read side of the weekly sheets, against the stand-in reporting
  # database: the queries the ingest tests fake.
  class TrendStagingTest < ActiveSupport::TestCase
    setup do
      connection = Base.connection

      connection.create_table(CommitStaging.table_name, id: false, force: true) do |t|
        Csr::Commit::ColumnMap.select_columns.each { |column| column.start_with?("F") ? t.float(column) : t.string(column) }
        t.string :NoName14
        t.datetime :loaded_at
      end
      commit_row("NoName2" => "Customer", "NoName3" => "Delivery Address", "NoName4" => "CPN",
                 "NoName5" => "Part", "NoName6" => "MPN", "NoName14" => "")
      commit_row("NoName4" => "CPN-900", "NoName6" => "MPN-Z", "NoName14" => "Forecast", "F18" => 4000.0)
      commit_row("NoName4" => "CPN-900", "NoName6" => "MPN-Z", "NoName14" => "Balance", "F18" => -4000.0)

      connection.create_table(VerticalCommitStaging.table_name, id: false, force: true) { |t| t.string :DATE }
      %w[Date Past 1/2/2027 10/3/2026 10/3/2026 Future].each do |date|
        connection.insert_fixture({ "DATE" => date }, VerticalCommitStaging.table_name)
      end
    end

    teardown do
      [ CommitStaging, VerticalCommitStaging ].each { |staging| Base.connection.drop_table(staging.table_name, if_exists: true) }
    end

    test "reads only the rows of its own type, with the mapped columns" do
      rows = CommitStaging.rows

      assert_equal 1, rows.size
      assert_equal [ "CPN-900", "MPN-Z", -4000.0 ], rows.first.values_at("NoName4", "NoName6", "F18")
      assert_equal 3, CommitStaging.count
    end

    test "tells a load's time and its age" do
      assert_equal Time.zone.local(2026, 10, 12, 10, 41), CommitStaging.watermark
      assert_operator CommitStaging.age, :>, 0
    end

    test "the header row has to name the columns the way the map reads them" do
      assert_predicate CommitStaging, :layout_ok?

      # A column added before CPN: every label sits one column to the right.
      CommitStaging.connection.execute(%(UPDATE "CSR_CustomerCommitment" SET "NoName5" = 'CPN', "NoName4" = 'New column' WHERE "NoName2" = 'Customer'))

      assert_not_predicate CommitStaging, :layout_ok?
    end

    test "the first week is the earliest date, read the American way" do
      assert_equal Date.new(2026, 10, 3), VerticalCommitStaging.first_week
      assert_equal Date.new(2027, 1, 2), VerticalCommitStaging.parse("1/2/2027"), "January 2, not February 1"
      assert_nil VerticalCommitStaging.parse("Past")
    end

    private

    def commit_row(values)
      Base.connection.insert_fixture(values.merge("loaded_at" => "2026-10-12 10:41:00"), CommitStaging.table_name)
    end
  end
end
